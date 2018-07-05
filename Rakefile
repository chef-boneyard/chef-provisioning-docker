require "bundler"
require "bundler/gem_tasks"

task :spec do
  require File.expand_path("spec/run")
end

require "github_changelog_generator/task"

GitHubChangelogGenerator::RakeTask.new :changelog do |config|
  config.future_release = Chef::Provisioning::DockerDriver::VERSION
  config.enhancement_labels = "enhancement,Enhancement,New Feature,Improvement".split(",")
  config.bug_labels = "bug,Bug,Improvement,Upstream Bug".split(",")
  config.exclude_labels = "duplicate,question,invalid,wontfix,no_changelog,Exclude From Changelog,Question".split(",")
end
