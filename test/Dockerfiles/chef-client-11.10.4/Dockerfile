# DOCKER-VERSION 0.9
FROM phusion/baseimage:0.9.9
MAINTAINER Tom Duffield "tom@getchef.com"

ENV HOME /root
RUN /etc/my_init.d/00_regen_ssh_host_keys.sh
CMD ["/sbin/my_init"]

RUN apt-get -y update
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install curl build-essential libxml2-dev libxslt-dev git
RUN curl -L https://www.opscode.com/chef/install.sh | bash
RUN mkdir /etc/chef 
ADD validation.pem /etc/chef/validation.pem
ADD client.rb /etc/chef/client.rb
ENV PATH /opt/chef/embedded/bin:/opt/chef/bin:$PATH
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
