require 'chef_metal_docker'
with_provisioner ChefMetalDocker::DockerProvisioner.new

base_port = 27020

1.upto(2) do |i|
  port = base_port + i

  machine "mongodb#{i}" do
    provisioner_options :image_name => 'org/ubuntu:mongodb',
      :seed_command => :chef_client_service,
      :run_options => {
        :port => "#{port}:#{port}"
      }
    recipe 'mongodb::replicaset'
    attribute %w(mongodb config host), node['fqdn']
    attribute %w(mongodb config port), port
  end
end

