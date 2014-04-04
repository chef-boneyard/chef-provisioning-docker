# DOCKER-VERSION 0.9
FROM ubuntu:12.04
MAINTAINER Tom Duffield "tom@getchef.com"

RUN apt-get -y update
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install curl build-essential libxml2-dev libxslt-dev git
RUN curl -L https://www.opscode.com/chef/install.sh | bash
RUN echo "gem: --no-ri --no-rdoc" > ~/.gemrc
ENV PATH /opt/chef/embedded/bin:/opt/chef/bin:$PATH
