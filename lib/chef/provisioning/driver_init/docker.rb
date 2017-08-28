require 'chef/provisioning/docker_driver/driver'

Chef::Provisioning.register_driver_class('docker', Chef::Provisioning::DockerDriver::Driver)
