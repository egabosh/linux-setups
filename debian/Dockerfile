FROM debian:latest
ARG VERSION
ENV VERSION=${VERSION}
ARG BUILD_DATE
ENV BUILD_DATE=${BUILD_DATE}
ARG DESCRIPTION
ENV DESCRIPTION=${DESCRIPTION}
LABEL org.opencontainers.image.source="https://github.com/egabosh/linux-setups" \
      org.opencontainers.image.description=$DESCRIPTION \
      org.opencontainers.image.version=$VERSION \
      org.opencontainers.image.authors="Oliver Bohlen (aka olli/egabosh)" \
      org.opencontainers.image.licenses="GPL-3.0 (for gaboshlib in /etc/bash/gaboshlib)" \
      org.opencontainers.image.created=$BUILD_DATE \
      org.opencontainers.image.vendor="egabosh" \
      org.opencontainers.image.documentation="https://github.com/egabosh/linux-setups/#readme" \
      org.opencontainers.image.base.name="Debian Linux" \
      org.opencontainers.image.base.licenses="Various, see https://www.debian.org/legal/licenses/"
ARG PIP_PACKAGES
ENV PIP_PACKAGES=${PIP_PACKAGES}
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
  apt-get -y dist-upgrade && \
  apt-get install -y curl && \
  curl -L https://github.com/egabosh/linux-setups/raw/refs/heads/main/debian/docker/build-debian-env.sh >build-debian-env.sh && \
  bash -ex build-debian-env.sh && \
  apt-get -y remove --purge postfix zip whois && \
  apt-get -y autoremove && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*
