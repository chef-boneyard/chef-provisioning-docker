source "https://supermarket.chef.io"

cookbook "docker", ">= 2.5.8"

group :integration do
  cookbook "ubuntu"
  cookbook "yum-epel"
  cookbook "openssh"
  cookbook "docker-tests", :path => "./test/integration/cookbooks/docker-tests"
end
