require 'chef/provider/lwrp_base'

class Chef::Provider::DockerContainer < Chef::Provider::LWRPBase

  def whyrun_supported?
    true
  end

  def load_current_resource
    # Don't do this here...
  end

  action :create do

  end

  action :delete do

  end

end
