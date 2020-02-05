# nordaaker/convos
#
# See https://convos.by/doc/config.html for details about the environment variables
#
# BUILD: docker build --no-cache --rm -t nordaaker/convos .
# RUN:   docker run -it --rm -p 8080:3000 -v /var/convos/data:/data nordaaker/convos
FROM alpine:3.11
MAINTAINER jhthorsen@cpan.org

RUN mkdir /app && \
  apk add --no-cache perl perl-io-socket-ssl wget && \
  apk add --no-cache --virtual builddeps build-base perl-dev

COPY Changes /app/
COPY cpanfile /app/
COPY assets /app/assets/
COPY lib /app/lib/
COPY public /app/public/
COPY script /app/script/
COPY templates /app/templates/

ENV CONVOS_CPAN_FILE /app/cpanfile
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
