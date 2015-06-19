require 'spec_helper'
require 'time'

describe "chef-provisioning-docker" do
  extend DockerSupport
  include DockerConfig

  when_the_chef_12_server "exists", organization: "foo", server_scope: :context, port: 8900..9000 do
    with_docker "integration tests" do

      # owing to how RSpec works, things defined by let() are not accessible in the recipes we define inside
      # expect_converge{}.
      ubuntu_options = {
          :base_image => {
            :name => 'ubuntu',
            :repository => 'ubuntu',
            :tag => '14.04'
          },
        }

      let(:iso_date) { Time.now.iso8601.gsub(':', '') }
      docker_driver = driver

      context "machine_image resource" do

        let(:spec_image_tag) { "docker_image_spec_#{iso_date}" }

        after(:each) {
          image = docker_driver.find_image("chef", spec_image_tag)
          image.delete(force: true) unless image.nil?
        }

        it ":create succeeds" do
          tag = spec_image_tag

          expect_converge {

            machine_image tag do
              machine_options :docker_options => ubuntu_options
              action :create
            end
          }.not_to raise_error

          expect(docker_driver.find_image("chef", tag)).not_to be_nil
        end

        it ":destroy succeeds with an existing image" do
          tag = spec_image_tag

          expect_converge {
            machine_image tag do
              machine_options :docker_options => ubuntu_options
              action :create
            end

            machine_image tag do
              action :destroy
            end
          }.not_to raise_error

          expect(docker_driver.find_image("chef", tag)).to be_nil
        end

        it ":destroy succeeds with a non-existent image" do
          tag = "bogus_image"
          expect_converge {
            machine_image tag do
              action :destroy
            end
          }.not_to raise_error
        end
      end
    end
  end
end