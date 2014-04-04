require 'chef_metal_docker'
with_provisioner ChefMetalDocker::DockerProvisioner.new
with_provisioner_options(
  :image_name => 'busybox',
  :seed_command => 'echo "Ohai Chefs!!"',
  :run_options => {
  }
)

machine 'busybox' do
  action :delete
end

machine 'busybox1' do
  provisioner_options :image_name => 'busybox',
    :seed_command => 'echo "Ohai #ChefConf!"',
    :run_options => {}
  action :delete
end

machine 'bubbles' do
  provisioner_options :image_name => 'busybox',
    :seed_command => 'echo "Ohai Tom"'
end

