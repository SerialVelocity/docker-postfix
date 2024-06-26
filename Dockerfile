FROM debian:stable-slim AS postfix

ARG POSTFIX_VERSION

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates wget && \
    apt-get clean

RUN wget -qO- "https://postfix.mirrors.ovh.net/postfix-release/official/postfix-${POSTFIX_VERSION}.tar.gz" | tar xz

RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc icu-devtools libc6-dev libdb-dev libicu-dev libldap2-dev libpcre3-dev libsasl2-dev libssl-dev m4 make pkg-config && \
    apt-get clean

RUN cd "/postfix-${POSTFIX_VERSION}" && \
    make makefiles pie=yes shared=yes dynamicmaps=yes CCARGS='-DHAS_LDAP -DHAS_PCRE -DUSE_SASL_AUTH -DUSE_CYRUS_SASL -I/usr/include/sasl -DDEF_SERVER_SASL_TYPE=\"dovecot\" -DUSE_TLS' AUXLIBS="-lssl -lcrypto -lsasl2" AUXLIBS_LDAP="-lldap -llber" AUXLIBS_PCRE="$(pcre-config --libs)" && \
    make -j5

RUN cd "/postfix-${POSTFIX_VERSION}" && \
    make non-interactive-package install_root=/pkg

# Copy doesn't work as there is a symlink at the destination: /usr/local/man -> share/man
RUN mkdir -p /pkg/usr/local/share/man && \
    mv /pkg/usr/local/man/* /pkg/usr/local/share/man/ && \
    rmdir /pkg/usr/local/man



FROM debian:stable-slim AS s6-overlay

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates wget && \
    apt-get clean

RUN mkdir /pkg && \
    wget -qO- https://github.com/just-containers/s6-overlay/releases/download/v1.21.8.0/s6-overlay-amd64.tar.gz | tar xvz -C /pkg && \
    wget -qO- https://github.com/just-containers/socklog-overlay/releases/download/v3.1.0-2/socklog-overlay-amd64.tar.gz | tar xvz -C /pkg

# Copy doesn't work as there is a symlink at the destination: /bin -> usr/bin
RUN mkdir -p /pkg/usr/bin && \
    mv /pkg/bin/* /pkg/usr/bin/ && \
    rmdir /pkg/bin



FROM debian:stable-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends libc6 libdb5.3 libicu72 libldap-2.5-0 libpcre3 libsasl2-2 libsasl2-modules libsasl2-modules-ldap libssl3 netbase sasl2-bin libnsl2 && \
    apt-get clean

COPY --from=postfix /pkg/ /
COPY --from=s6-overlay /pkg/ /

RUN groupadd -g 9991 postfix && \
    groupadd -g 9992 postdrop && \
    useradd -u 9991 -d /var/spool/postfix -g postfix -G sasl -s /bin/false postfix

RUN postfix set-permissions upgrade-configuration mail_owner=postfix setgid_group=postdrop

COPY rootfs/ /

ENTRYPOINT ["/init"]
CMD ["postfix", "start-fg"]
