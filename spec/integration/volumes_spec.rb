require 'spec_helper'
require 'time'
require 'fileutils'

describe "chef-provisioning-docker" do
  extend DockerSupport
  include DockerConfig

  when_the_chef_12_server "exists", organization: "foo", server_scope: :context, port: 8900..9000 do
    with_docker "volumes supported" do

      # owing to how RSpec works, things defined by let() are not accessible in the recipes we define inside
      # expect_converge{}.
      ubuntu_options = {
          :base_image => {
            :name => 'ubuntu',
            :repository => 'ubuntu',
            :tag => '14.04'
          }
        }

      let(:timestamp) { Time.now.to_i }
      docker_driver = driver

      context "machine_image resource" do

        let(:spec_image_tag) { "docker_image_spec_#{timestamp}" }

        after(:each) {
          image = docker_driver.find_image("chef", "#{spec_image_tag}")
          image.delete(force: true) unless image.nil?
          FileUtils.rm_rf("/tmp/opt")
          FileUtils.rm_rf("/tmp/#{spec_image_tag}")
        }

        it "installs chef omnibus on the volume" do
          tag = spec_image_tag

          expect_converge {

            machine_image tag do
              machine_options :docker_options => ubuntu_options
              action :create
            end
          }.not_to raise_error

          expect(File.exists?("/tmp/opt/chef/bin/chef-client")).to be_truthy
        end

        it "installs chef omnibus on specific volume" do
          tag = spec_image_tag

          expect_converge {

            machine_image tag do
              machine_options :docker_options => ubuntu_options,
                :convergence_options => {
                  :chef_volume => "/tmp/#{tag}/chef"
                }
              action :create
            end
          }.not_to raise_error

          expect(File.exists?("/tmp/#{tag}/chef/bin/chef-client")).to be_truthy
        end


        it "mounts volume during converge" do
          tag = spec_image_tag

          expect_converge {

            machine_image tag do
              machine_options :docker_options => ubuntu_options.merge({:volumes => "/tmp/#{tag}:/var/chef/cache/"})
              action :create
            end
          }.not_to raise_error

          expect(File.exists?("/tmp/#{tag}/chef-client-running.pid")).to be_truthy
        end
      end

      context "machine resource" do
        let(:spec_machine_name) { "docker_machine_spec_#{timestamp}" }

        after(:each) {
          container = docker_driver.find_container(spec_machine_name)
          container.delete(:force => true) unless container.nil?
          FileUtils.rm_rf("/tmp/opt/chef")
          FileUtils.rm_rf("/tmp/#{spec_machine_name}")
        }

        it "mounts volume" do
          name = spec_machine_name

          expect_converge {

            machine name do
              machine_options :docker_options => ubuntu_options.merge({
                :volumes => "/tmp/#{name}:/tmp/spec",
                :command => "/bin/bash -c 'echo \"Hi there!\" > /tmp/spec/i_exist' ; sleep 10000",
              })
              action :converge
            end
          }.not_to raise_error

          expect(docker_driver.find_container(spec_machine_name)).not_to be_nil
          expect(File.exists?("/tmp/#{name}/i_exist")).to be_truthy
        end
      end
    end
  end
end
