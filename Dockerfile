FROM ubuntu
RUN echo "deb http://archive.ubuntu.com/ubuntu precise main universe" >> /etc/apt/sources.list
RUN apt-get update
RUN apt-get upgrade
RUN apt-get -y install curl perl supervisor redis-server make rubygems
ADD ./vendor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
ADD . /convos
RUN gem install sass
RUN cd /convos; ./vendor/bin/carton
EXPOSE 5000 
EXPOSE 6379
CMD ["supervisord", "-n"]
