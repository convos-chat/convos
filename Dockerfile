# convos/convos
#
# See https://convos.chat/doc/config.html for details about the environment variables
#
# BUILD: docker build --no-cache --rm -t convos/convos .
# RUN:   docker run -it --rm -p 8080:3000 -v /var/convos/data:/data convos/convos
FROM alpine:3.14
LABEL maintainer="jhthorsen@cpan.org"

RUN mkdir /app
COPY Changes cpanfile /app/
COPY assets /app/assets
COPY lib /app/lib
COPY public /app/public
COPY script /app/script
COPY templates /app/templates

RUN apk add --no-cache curl openssl perl perl-io-socket-ssl perl-net-ssleay wget && \
    apk add --no-cache --virtual builddeps build-base perl-dev && \
    curl -vfsSL --compressed https://git.io/cpm > /tmp/cpm && \
    chmod 0755 /tmp/cpm && \
    /tmp/cpm install --no-show-progress --no-test --show-build-log-on-failure --with-all --feature bot --cpanfile /app/cpanfile -g && \
    apk del builddeps && \
    rm -rf /tmp/cpm /root/.cpanm /var/cache/apk/*

# Do not change these variables unless you know what you're doing
ENV CONVOS_HOME /data
ENV CONVOS_NO_ROOT_WARNING 1
ENV MOJO_MODE production

VOLUME ["/data"]
EXPOSE 3000

CMD ["daemon"]
ENTRYPOINT ["/app/script/convos"]
