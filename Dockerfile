# nordaaker/convos
#
# See https://convos.by/doc/config.html for details about the environment variables
#
# BUILD: docker build --no-cache --rm -t nordaaker/convos .
# RUN:   docker run -it --rm -p 8080:3000 -v /var/convos/data:/data nordaaker/convos
FROM alpine:3.10
MAINTAINER jhthorsen@cpan.org

# ENV CONVOS_INVITE_CODE some_super_long_and_secret_string
# ENV CONVOS_SECRETS some_other_super_long_and_secret_string
# ENV CONVOS_DEFAULT_SERVER chat.freenode.net:6697
# ENV CONVOS_FORCED_IRC_SERVER 0
# ENV CONVOS_PLUGINS ShareDialog,OtherCustomPlugin
ENV CONVOS_CONTACT mailto:root@localhost
ENV CONVOS_ORGANIZATION_NAME Nordaaker
ENV CONVOS_ORGANIZATION_URL http://nordaaker.com
ENV CONVOS_SECURE_COOKIES 0

RUN mkdir /app && \
  apk add --no-cache perl perl-io-socket-ssl wget && \
  apk add --no-cache --virtual builddeps build-base perl-dev

COPY Changes /app
COPY cpanfile /app
COPY assets /app/assets
COPY lib /app/lib
COPY public /app/public
COPY script /app/script
COPY templates /app/templates

RUN /app/script/convos install
RUN apk del builddeps && rm -rf /root/.cpanm /var/cache/apk/*

# Do not change these variables unless you know what you're doing
ENV CONVOS_HOME /data
ENV CONVOS_NO_ROOT_WARNING 1
ENV MOJO_MODE production

VOLUME ["/data"]
EXPOSE 3000

CMD ["daemon"]
ENTRYPOINT ["/app/script/convos"]
