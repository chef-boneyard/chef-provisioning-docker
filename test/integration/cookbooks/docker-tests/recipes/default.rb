case node.platform_family
when 'ubuntu', 'debian'
  include_recipe 'ubuntu'
  include_recipe 'apt-docker'
when 'rhel'
  include_recipe 'yum-epel'
  include_recipe 'yum-docker'
end

docker_service 'default' do
  version '1.10.2'
end

ENV['CHEF_DRIVER'] = 'docker'

bash 'build and install chef-provisioning-docker' do
  cwd '/opt/chef-provisioning-docker'
  code <<-EOS
    rm -f chef-provisioning-docker-*.gem
    /opt/chef/embedded/bin/gem build chef-provisioning-docker.gemspec
  EOS
  action :nothing
end.run_action(:run)

chef_gem 'chef-provisioning-docker' do
  source Dir[ '/opt/chef-provisioning-docker/*.gem' ].first
  clear_sources true
  action [:remove, :install]
end

require 'chef/provisioning/docker_driver'
