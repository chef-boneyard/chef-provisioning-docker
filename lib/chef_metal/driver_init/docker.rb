require 'chef_metal_docker/docker_driver'

ChefMetal.register_driver_class('docker', ChefMetalDocker::DockerDriver)
