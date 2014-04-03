require 'chef/provider/lwrp_base'
require 'chef_metal_docker/helpers/container'

class Chef::Provider::DockerContainer < Chef::Provider::LWRPBase

  include ChefMetalDocker::Helpers::Container

  def whyrun_supported?
    true
  end

  def load_current_resource
    @current_resource = Chef::Resource::DockerContainer.new(new_resource)
    wait_until_ready!
    docker_containers.each do |ps|
      unless container_id_matches?(ps['id'])
        next unless container_image_matches?(ps['image'])
        next unless container_command_matches_if_exists?(ps['command'])
        next unless container_name_matches_if_exists?(ps['names'])
      end
      Chef::Log.debug('Matched docker container: ' + ps['line'].squeeze(' '))
      @current_resource.container_name(ps['names'])
      @current_resource.created(ps['created'])
      @current_resource.id(ps['id'])
      @current_resource.status(ps['status'])
      break
    end
    @current_resource
  end

  action :commit do
    if exists?
      converge_by("create docker image based on #{current_resource.id}") do
        commit
      end
    end
  end

  action :cp do
    if exists?
      converge_by("copy #{new_resource.source} from #{current_resource.id} to #{new_resource.desitnation}") do
        cp
      end
    end
  end

  action :export do
    if exists?
      converge_by("export the contents of #{current_resource.id} to #{new_resource.desitniation}") do
        export
      end
    end
  end

  action :kill do
    if running?
      converge_by("kill container #{current_resource.id}") do
        kill
      end
    end
  end

  action :redeploy do
    converge_by("redeploy container #{current_resource.id}") do
      redeploy
    end
  end

  action :remove do
    if running?
      converge_by("stop container #{current_resource.id}") do
        stop
      end
    end
    if exists?
      converge_by("remove container #{current_resource.id}") do
        remove
      end
    end
  end

  action :restart do
    if exists?
      converge_by("restart container #{current_resource.id}") do
        restart
      end
    end
  end

  action :run do
    unless running?
      if exists?
        converge_by("container #{current_resource.id} already exists...starting") do
          start
        end
      else
        converge_by("run container #{current_resource.id}") do
          run
        end
      end
    end
  end

  action :start do
    unless running?
      converge_by("start container #{current_resource.id}") do
        start
      end
    end
  end

  action :stop do
    if running?
      converge_by("stop container #{current_resource.id}") do
        stop
      end
    end
  end

  action :wait do
    if running?
      converge_by("tell container #{current_resource.id} to wait") do
        wait
      end
    end
  end
end
