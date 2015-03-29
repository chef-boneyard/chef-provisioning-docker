require 'chef/dsl/recipe'

module Chef::DSL::Recipe
  def with_docker_host(machine_name, &recipe)
    # TODO I feel like connect_to_machine should get the chef_server for me
    chef_server = run_context.cheffish.current_chef_server
    docker_host = run_context.chef_provisioning.connect_to_machine(machine_name, chef_server)

    # Figure out the IP of the server on the docker0 subnet, so we can write
    # that to its client.rb
    result = docker_host.execute_always('ifconfig docker0', :read_only => true)
    Chef::Log.debug("ifconfig docker0: #{result.stdout}")
    if result.stdout =~ /\binet addr:(\S+)/
      docker_host_ip = $1
    else
      raise "ifconfig docker0 failed to produce a default route on the docker host: cannot provide the container with a working Chef server URL.\nSTDOUT:\n#{result.stdout}\nSTDERR:\n#{result.stderr}"
    end

    # SSH will listen on docker_host_ip, and forward to our Chef server.
    chef_server_url = docker_host.make_url_available_to_remote(chef_server[:chef_server_url], bind_to: docker_host_ip)

    # We will talk to the docker API itself via the SSH connection, since it isn't generally exposed directly to the outside world.
    docker_api_url = docker_host.make_remote_url_available_locally('tcp://127.0.0.1:5555')

    with_driver("docker:#{docker_api_url}") { recipe.call(chef_server_url) }
  end
end
