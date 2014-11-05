require 'chef/provisioning/docker_driver/driver'

ChefMetal.register_driver_class('docker', Chef::Provisioning::DockerDriver::Driver)
