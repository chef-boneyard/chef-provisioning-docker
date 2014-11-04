require 'chef/provisioning/docker_driver'
with_provisioner Chef::Provisioning::DockerDriver::DockerProvisioner.new

base_port = 27020

1.upto(2) do |i|
  port = base_port + i

  machine "mongodb#{i}" do
    provisioner_options :image_name => 'chef/ubuntu_12.04:11.10.4',
      :seed_command => 'chef-client -d -o mongodb::replicaset',
      :run_options => {
        :port => "#{port}:#{port}",
        :env => [
          'CONTAINER_NAME' => "mongodb#{i}",
          'CHEF_SERVER_URL' => 'https://api.opscode.com/organizations/tomduffield-personal',
          'VALIDATION_CLIENT_NAME' => 'tomduffield-personal-validator'
        ]
      }
    recipe 'mongodb::replicaset'
    attribute %w(mongodb config host), node['fqdn']
    attribute %w(mongodb config port), port
  end
end
