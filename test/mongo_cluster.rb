
machine "ubuntu_chef_client" do
  provisioner_option :image_name => 'ubuntu',
    :seed_command => '',
    :run_options => {

    }
end

machine_image "org/ubuntu:11.10.4" do
  machine 'ubuntu_chef_client'
end

machine 'ubuntu_chef_client' do
  action :delete
end

# The following three resources would become image_factory
machine "ubuntu_mongodb" do
  # this is where we would create org/ubuntu:11.10.4
  provisioner_options :image_name => 'chef/ubuntu_12.04:11.10.4',
    :seed_command => :chef_client,
    :run_options => {
    }
  recipe 'mongodb::replicaset'
end

machine_image 'org/ubuntu:mongodb' do
  machine "ubuntu_mongodb"
end

machine "org/ubuntu:mongodb" do
  action :delete
end

machine 'cluster1' do
  recipe 'mongo_host'
end

machine 'cluster2' do
  recipe 'mongo_host'
end
