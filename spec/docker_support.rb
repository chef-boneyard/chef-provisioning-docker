module DockerSupport
  require 'cheffish/rspec/chef_run_support'
  def self.extended(other)
    other.extend Cheffish::RSpec::ChefRunSupport
  end

  require 'chef/provisioning/docker_driver'

  def with_docker(description, *tags, &block)
    context_block = proc do
      docker_driver = Chef::Provisioning.driver_for_url("docker")

      @@driver = docker_driver
      def self.driver
        @@driver
      end

      module_eval(&block)
    end

    when_the_repository "exists and #{description}", *tags, &context_block
  end
end

module DockerConfig
  def chef_config
    @chef_config ||= {
      driver:       Chef::Provisioning.driver_for_url("docker"),
    }
  end
end
