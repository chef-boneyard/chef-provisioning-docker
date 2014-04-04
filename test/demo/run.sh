rm -rf ./cookbooks
#berks vendor ./cookbooks
docker run \
  -e CONTAINER_NAME=demo \
  -e CHEF_SERVER_URL=https://api.opscode.com/organizations/tomduffield-personal \
  -e VALIDATION_CLIENT_NAME=tomduffield-personal \
  -d \
  --name="demo" \
  chef/ubuntu_12.04:11.10.4 \
  bash -c 'while true; do sleep 100000; done'
