$:.unshift(File.dirname(__FILE__) + '/lib')
require 'chef_metal_docker/version'

Gem::Specification.new do |s|
  s.name = 'chef-metal-docker'
  s.version = ChefMetalDocker::VERSION
  s.platform = Gem::Platform::RUBY
  s.extra_rdoc_files = ['README.md', 'LICENSE' ]
  s.summary = 'Provisioner for creating Docker containers in Chef Metal.'
  s.description = s.summary
  s.author = 'Tom Duffield'
  s.email = 'tom@getchef.com'
  s.homepage = 'https://github.com/opscode/chef-metal-docker'

  s.add_dependency 'chef'
  s.add_dependency 'chef-metal', '~> 0.9'
  s.add_dependency 'docker-api'
  s.add_dependency 'em-proxy'

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rake'

  s.bindir       = "bin"
  s.executables  = %w( )

  s.require_path = 'lib'
  s.files = %w(Rakefile LICENSE README.md) + Dir.glob("{distro,lib,tasks,spec}/**/*", File::FNM_DOTMATCH).reject {|f| File.directory?(f) }
end
