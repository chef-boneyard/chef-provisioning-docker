# chef-metal-docker

How to use:

First you need to ensure that Docker is running. This can be done on a Linux host using Docker's installers or on OSX using boot2docker. Once you have that, you can install the dependencies with Bundler and then use the Docker driver like the following:

```  
CHEF_DRIVER=docker bundle exec chef-client -z docker_ubuntu_image.rb
```   

This will run Chef-zero and use the description stored in docker_ubuntu_image.rb (the second example below). Note that some configuration syntax is likely to change a little bit so be sure to check the documentation. 

## Machine creation

Using this driver, you can then define a machine similar to the following example:

```ruby   
require 'chef_metal_docker'

machine 'wario' do
    recipe 'openssh::default'
    
    machine_options :docker_options => {
      :base_image => {
          :name => 'ubuntu',
          :repository => 'ubuntu',
          :tag => '14.04'
      },
      :command => '/usr/sbin/sshd -p 8022 -D',
      :ports => 8022
      # if you need to keep stdin open (i.e docker run -i)
      # :keep_stdin_open => true

    }
end
```

This will create a docker container based on Ubuntu 14.04 and
then execute the Apache recipe and run the /usr/sbin/httpd command
as the container's run command. 

## Machine images

This driver supports the new machine image paradigm; with Docker you can build a base image, save that and use it to create a new container. Here is an example of this:

```ruby
require 'chef_metal_docker'

machine_image 'web_server' do
  recipe 'apache'

  machine_options :docker_options => {
      :base_image => {
          :name => 'ubuntu',
          :repository => 'ubuntu',
          :tag => '14.04'
      }
  }
end

machine 'web00' do
  from_image 'web_server'

  machine_options :docker_options => {
      :command => '/usr/sbin/httpd'
  }
end
```
