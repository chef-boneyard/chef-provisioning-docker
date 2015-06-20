source 'https://supermarket.chef.io'

group :integration do
  cookbook 'ubuntu'
  cookbook 'yum-epel'
  cookbook 'openssh'
  cookbook 'docker-tests', :path => './test/integration/cookbooks/docker-tests'
end
