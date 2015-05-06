# chef-provisioning-docker

How to use:

First you need to ensure that Docker is running. This can be done on a Linux host using Docker's installers or on OSX using boot2docker. Once you have that, you can install the dependencies with Bundler and then use the Docker  like the following:

```  
CHEF_DRIVER=docker bundle exec chef-client -z docker_ubuntu_image.rb
```   

This will run Chef-zero and use the description stored in docker_ubuntu_image.rb (the second example below). Note that some configuration syntax is likely to change a little bit so be sure to check the documentation. 

## Machine creation

Using this , you can then define a machine similar to the following example:

```ruby
require 'chef/provisioning/docker_driver'

machine 'wario' do
    recipe 'openssh::default'

    machine_options :docker_options => {
      :base_image => {
          :name => 'ubuntu',
          :repository => 'ubuntu',
          :tag => '14.04'
      },
      :command => '/usr/sbin/sshd -p 8022 -D',

      #ENV (Environment Variables)
      #Set any env var in the container by using one or more -e flags, even overriding those already defined by the developer with a Dockerfile ENV
      :env => {
         "deep" => 'purple',
         "led" => 'zeppelin'
      },

      # Ports can be one of two forms:
      # src_port (string or integer) is a pass-through, i.e 8022 or "9933"
      # src:dst (string) is a map from src to dst, i.e "8022:8023" maps 8022 externally to 8023 in the container

      # Example (multiple):
      :ports => [8022, "8023:9000", "9500"],

      # Examples (single):
      :ports => 1234,
      :ports => "2345:6789",

      # Volumes can be one of three forms:
      # src_volume (string) is volume to add to container, i.e. creates new volume inside container at "/tmp"
      # src:dst (string) mounts host's directory src to container's dst, i.e "/tmp:/tmp1" mounts host's directory /tmp to container's /tmp1
      # src:dst:mode (string) mounts host's directory src to container's dst with the specified mount option, i.e "/:/rootfs:ro" mounts read-only host's root (/) folder to container's /rootfs
      # See more details on Docker volumes at https://github.com/docker/docker/blob/master/docs/sources/userguide/dockervolumes.md .

      # Example (single):
      :volumes => "/tmp",

      # Example (multiple):
      :volumes => ["/tmp:/tmp", "/:/rootfs:ro"],

      # if you need to keep stdin open (i.e docker run -i)
      # :keep_stdin_open => true

    }
end
```

This will create a docker container based on Ubuntu 14.04 and
then execute the Apache recipe and run the /usr/sbin/httpd command
as the container's run command. 

## Machine images

This  supports the new machine image paradigm; with Docker you can build a base image, save that and use it to create a new container. Here is an example of this:

```ruby
require 'chef/provisioning/docker_driver'

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
