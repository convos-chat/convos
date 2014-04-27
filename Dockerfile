# nordaaker/convos
# VERSION 0.0.1
#
# BUILD: docker build --no-cache --rm -t nordaaker/convos .
# RUN:   docker run -p $PORT:8080 nordaaker/convos

FROM   ubuntu:13.10
ENV    DEBIAN_FRONTEND noninteractive

#RUN    dpkg-divert --local --rename --add /sbin/initctl
#RUN    ln -s /bin/true /sbin/initctl

RUN    apt-get --yes update
RUN    apt-get --yes upgrade --force-yes
RUN    apt-get install -y -q software-properties-common

RUN    apt-get -y install curl perl supervisor redis-server make rubygems libio-socket-ssl-perl
ADD    ./vendor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
ADD    . /convos
RUN    gem install sass
RUN    cd /convos; ./vendor/bin/carton

EXPOSE 8080
CMD    cd /convos && ./setup_config.sh && /usr/bin/supervisord
