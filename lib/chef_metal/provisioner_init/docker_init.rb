require 'chef_metal_docker/docker_provisioner'

ChefMetal.add_registered_provisioner_class("docker",
  ChefMetalDocker::DockerProvisioner)
