require 'chef_metal_docker'
with_provisioner ChefMetalDocker::DockerProvisioner.new
with_provisioner_options(
  :image_name => 'busybox',
  :seed_command => 'echo "Ohai Chefs!!"',
  :run_options => {
  }
)

machine 'busybox'

