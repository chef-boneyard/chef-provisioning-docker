# chef-metal-docker

How to use:

1.Ensure that Docker is running 

2. Define a machine similar to the following example:

    require 'chef_metal_docker'
    
    machine 'wario' do
      recipe 'apache'
    
      machine_options :docker_options => {
        :base_image => {
            :name => 'ubuntu',
            :repository => 'ubuntu',
            :tag => '14.04'
        },
    
        :command => '/usr/sbin/httpd'
      }
    
    end
    
This will create a docker container based on Ubuntu 14.04 and
then execute the Apache recipe and run the /usr/sbin/httpd command
as the container's run command. 


(or) 3. Build a base image and use that as in this example:


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

