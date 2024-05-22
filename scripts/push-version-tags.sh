#!/usr/bin/env bash

set -euo pipefail

IMAGE_NAME="${DOCKER_REPO}:${CIRCLE_TAG}"

MAJOR_MINOR_PATCH_VERSION="${CIRCLE_TAG}"
MAJOR_MINOR_VERSION=$(sed -E 's/\.[0-9]+$//' <<< "${MAJOR_MINOR_PATCH_VERSION}")
MAJOR_VERSION=$(sed -E 's/\.[0-9]+$//' <<< "${MAJOR_MINOR_VERSION}")

git tag -l | xargs git tag --delete
git fetch --tags --prune origin

docker push "${IMAGE_NAME}"

if [[ "${MAJOR_MINOR_PATCH_VERSION}" == "$(git tag -l | grep -E "^$(sed "s#\(\\.\)#\\\\\\1#g" <<< "${MAJOR_MINOR_VERSION}")\\." | sort -V | tail -n 1)" ]]; then
    docker tag "${IMAGE_NAME}" "${DOCKER_REPO}:${MAJOR_MINOR_VERSION}"
    docker push "${DOCKER_REPO}:${MAJOR_MINOR_VERSION}"
else
    echo "Not tagging ${MAJOR_MINOR_VERSION} because ${MAJOR_MINOR_PATCH_VERSION} is not the latest"
fi

if [[ "${MAJOR_MINOR_PATCH_VERSION}" == "$(git tag -l | grep -E "^$(sed "s#\(\\.\)#\\\\\\1#g" <<< "${MAJOR_VERSION}")\\." | sort -V | tail -n 1)" ]]; then
    docker tag "${IMAGE_NAME}" "${DOCKER_REPO}:${MAJOR_VERSION}"
    docker push "${DOCKER_REPO}:${MAJOR_VERSION}"
else
    echo "Not tagging ${MAJOR_VERSION} because ${MAJOR_MINOR_PATCH_VERSION} is not the latest"
fi
