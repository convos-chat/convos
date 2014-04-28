# nordaaker/convos
# VERSION 0.0.1
#
# BUILD: docker build --no-cache --rm -t nordaaker/convos .
# RUN:   docker run -p $PORT:8080 nordaaker/convos

FROM   ubuntu:13.10
ENV    DEBIAN_FRONTEND noninteractive

#RUN    dpkg-divert --local --rename --add /sbin/initctl
#RUN    ln -s /bin/true /sbin/initctl

RUN    apt-get update && apt-get install -y \
       software-properties-common \
       curl \
       perl \
       make \
       rubygems \
       libio-socket-ssl-perl \
       supervisor \
       redis-server

ADD    ./vendor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
ADD    . /convos
RUN    gem install sass
RUN    cd /convos; ./vendor/bin/carton

EXPOSE 8080
CMD    cd /convos && ./setup_config.sh && /usr/bin/supervisord
