# chef-metal-docker

How to use:

1.Ensure that Docker is running 

2. define a machine using the following:

    docker_container 'repository:tag' do
    
    end

Example:

    docker_container 'ubuntu:12.04' do
    end

