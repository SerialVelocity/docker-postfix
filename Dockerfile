FROM debian:stable-slim AS build

ARG POSTFIX_VERSION

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates wget && \
    apt-get clean

RUN wget -qO- "http://cdn.postfix.johnriley.me/mirrors/postfix-release/official/postfix-${POSTFIX_VERSION}.tar.gz" | tar xvz

RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc icu-devtools libc6-dev libdb-dev libicu-dev libldap2-dev libpcre3-dev libsasl2-dev libssl-dev m4 make pkg-config && \
    apt-get clean

RUN cd "/postfix-${POSTFIX_VERSION}" && \
    make makefiles pie=yes shared=yes dynamicmaps=yes CCARGS='-DHAS_LDAP -DHAS_PCRE -DUSE_SASL_AUTH -DUSE_CYRUS_SASL -I/usr/include/sasl -DDEF_SERVER_SASL_TYPE=\"dovecot\" -DUSE_TLS' AUXLIBS="-lssl -lcrypto -lsasl2" && \
    make -j5

RUN cd "/postfix-${POSTFIX_VERSION}" && \
    make non-interactive-package install_root=/pkg



FROM debian:stable-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends libc6 libdb5.3 libicu63 libldap-2.4-2 libpcre3 libsasl2-2 libssl1.1 netbase tini && \
    apt-get clean

COPY --from=build /pkg/ /

RUN groupadd -g 9991 postfix && \
    groupadd -g 9992 postdrop && \
    useradd -u 9991 -d /var/spool/postfix -g postfix -s /bin/false postfix

RUN postfix set-permissions upgrade-configuration mail_owner=postfix setgid_group=postdrop

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/sbin/postfix", "start-fg"]