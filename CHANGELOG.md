# Change Log

## [1.0.0.beta.3](https://github.com/chef/chef-provisioning-docker/tree/1.0.0.beta.3) (2016-03-24)
[Full Changelog](https://github.com/chef/chef-provisioning-docker/compare/v1.0.0.beta.2...1.0.0.beta.3)

**Merged pull requests:**

- fix explanation of the recipe [\#89](https://github.com/chef/chef-provisioning-docker/pull/89) ([jgoulah](https://github.com/jgoulah))
- remove logic that changes hostname to an ip [\#88](https://github.com/chef/chef-provisioning-docker/pull/88) ([jgoulah](https://github.com/jgoulah))
- don't pass empty volumes - fixes issue \#86 [\#87](https://github.com/chef/chef-provisioning-docker/pull/87) ([jgoulah](https://github.com/jgoulah))

## [v1.0.0.beta.2](https://github.com/chef/chef-provisioning-docker/tree/v1.0.0.beta.2) (2016-03-24)
[Full Changelog](https://github.com/chef/chef-provisioning-docker/compare/v1.0.0.beta.1...v1.0.0.beta.2)

**Closed issues:**

- volumes are not mounting properly [\#85](https://github.com/chef/chef-provisioning-docker/issues/85)
- Update /etc/hosts of Docker container [\#82](https://github.com/chef/chef-provisioning-docker/issues/82)
- chef server URL being set to "172.17.0.1" and fails SSL verify [\#79](https://github.com/chef/chef-provisioning-docker/issues/79)
- docker-machine support [\#78](https://github.com/chef/chef-provisioning-docker/issues/78)

**Merged pull requests:**

- Add all options [\#83](https://github.com/chef/chef-provisioning-docker/pull/83) ([jkeiser](https://github.com/jkeiser))

## [v1.0.0.beta.1](https://github.com/chef/chef-provisioning-docker/tree/v1.0.0.beta.1) (2016-03-11)
[Full Changelog](https://github.com/chef/chef-provisioning-docker/compare/v0.8.0...v1.0.0.beta.1)

**Merged pull requests:**

- Docker toolbox and chef-zero support [\#81](https://github.com/chef/chef-provisioning-docker/pull/81) ([jkeiser](https://github.com/jkeiser))

## [v0.8.0](https://github.com/chef/chef-provisioning-docker/tree/v0.8.0) (2016-02-03)
[Full Changelog](https://github.com/chef/chef-provisioning-docker/compare/v0.7...v0.8.0)

**Implemented enhancements:**

- Add gemspec files to allow bundler to run from the gem [\#68](https://github.com/chef/chef-provisioning-docker/pull/68) ([ksubrama](https://github.com/ksubrama))
- leverage exec for transport and implements connect\_to\_machine and stop\_machine [\#56](https://github.com/chef/chef-provisioning-docker/pull/56) ([mwrock](https://github.com/mwrock))

**Fixed bugs:**

- gemspec relies on very old chef-provisioning version [\#45](https://github.com/chef/chef-provisioning-docker/issues/45)

**Merged pull requests:**

- Bump revision to 0.8.0, add changelog generator [\#76](https://github.com/chef/chef-provisioning-docker/pull/76) ([jkeiser](https://github.com/jkeiser))

## [v0.7](https://github.com/chef/chef-provisioning-docker/tree/v0.7) (2015-06-22)
[Full Changelog](https://github.com/chef/chef-provisioning-docker/compare/v0.6...v0.7)

**Fixed bugs:**

- chef-provisioning-docker doesn't implement :destroy for machine\_image [\#50](https://github.com/chef/chef-provisioning-docker/issues/50)

**Closed issues:**

- Monkey patch EventOutputStream  [\#49](https://github.com/chef/chef-provisioning-docker/issues/49)
- Monkey patch EventOutputStream  [\#48](https://github.com/chef/chef-provisioning-docker/issues/48)
- Unable to activate chef-provisioning-docker-0.6 [\#46](https://github.com/chef/chef-provisioning-docker/issues/46)
- Connection to Docker image fails [\#44](https://github.com/chef/chef-provisioning-docker/issues/44)
- Chef::Exceptions::ContentLengthMismatch: Response body length 8006 does not match HTTP Content-Length header 12829 [\#38](https://github.com/chef/chef-provisioning-docker/issues/38)
- Machine image gets immediately deleted after creation [\#37](https://github.com/chef/chef-provisioning-docker/issues/37)
- NoMethodError: undefined method `\[\]' while creating machine from image [\#31](https://github.com/chef/chef-provisioning-docker/issues/31)
- Modify way of how use local image as base image [\#27](https://github.com/chef/chef-provisioning-docker/issues/27)
- Containers get created in a stopped state. [\#24](https://github.com/chef/chef-provisioning-docker/issues/24)

**Merged pull requests:**

- Clean up specs/dependencies/Gemfiles. [\#58](https://github.com/chef/chef-provisioning-docker/pull/58) ([randomcamel](https://github.com/randomcamel))
- Implement machine\_image :destroy, add specs [\#51](https://github.com/chef/chef-provisioning-docker/pull/51) ([randomcamel](https://github.com/randomcamel))
- Added support for chef-provisioning 1.0 [\#47](https://github.com/chef/chef-provisioning-docker/pull/47) ([marc-](https://github.com/marc-))
- re-order paragraphs so that they are attached to the right code snippet [\#43](https://github.com/chef/chef-provisioning-docker/pull/43) ([jamesc](https://github.com/jamesc))

## [v0.6](https://github.com/chef/chef-provisioning-docker/tree/v0.6) (2015-05-12)
[Full Changelog](https://github.com/chef/chef-provisioning-docker/compare/v0.5.2...v0.6)

**Closed issues:**

- In fresh container : /etc/chef/client.pem: no such file or directory [\#35](https://github.com/chef/chef-provisioning-docker/issues/35)
- NameError: undefined local variable or method `chef\_version' [\#30](https://github.com/chef/chef-provisioning-docker/issues/30)
- Add volumes support [\#29](https://github.com/chef/chef-provisioning-docker/issues/29)
- docker\_options/base\_image with docker-api v1.20.0 result in a 404 error [\#28](https://github.com/chef/chef-provisioning-docker/issues/28)
- Docker::Error::ServerError: Invalid registry endpoint on CentOS 7 [\#25](https://github.com/chef/chef-provisioning-docker/issues/25)

**Merged pull requests:**

- Added reference to Docker volumes documentation [\#41](https://github.com/chef/chef-provisioning-docker/pull/41) ([marc-](https://github.com/marc-))
- Added volumes support chef/chef-provisioning-docker\#29 [\#33](https://github.com/chef/chef-provisioning-docker/pull/33) ([marc-](https://github.com/marc-))

## [v0.5.2](https://github.com/chef/chef-provisioning-docker/tree/v0.5.2) (2015-02-26)
[Full Changelog](https://github.com/chef/chef-provisioning-docker/compare/v0.5.1...v0.5.2)

**Closed issues:**

- ERROR: Connection refused [\#23](https://github.com/chef/chef-provisioning-docker/issues/23)
- Will the re-write have the ability to do docker commands from the provisioning run? [\#5](https://github.com/chef/chef-provisioning-docker/issues/5)

## [v0.5.1](https://github.com/chef/chef-provisioning-docker/tree/v0.5.1) (2014-12-15)
[Full Changelog](https://github.com/chef/chef-provisioning-docker/compare/v0.5...v0.5.1)

**Fixed bugs:**

- Could not find the file /etc/chef/client.pem in container [\#13](https://github.com/chef/chef-provisioning-docker/issues/13)
- NoMethodError  `\<\<' for \#\<Chef::EventDispatch::EventsOutputStream:0x000000056423a0\> [\#9](https://github.com/chef/chef-provisioning-docker/issues/9)

**Closed issues:**

- Any plan to port this docker provisioner to the latest chef-metal v0.13 ? [\#2](https://github.com/chef/chef-provisioning-docker/issues/2)

**Merged pull requests:**

- Fix README typo: CHEF\_DRIVER env variable [\#19](https://github.com/chef/chef-provisioning-docker/pull/19) ([breezeight](https://github.com/breezeight))
- added env vars as parameters \#14 [\#15](https://github.com/chef/chef-provisioning-docker/pull/15) ([matiasdecarli](https://github.com/matiasdecarli))

## [v0.5](https://github.com/chef/chef-provisioning-docker/tree/v0.5) (2014-11-05)
[Full Changelog](https://github.com/chef/chef-provisioning-docker/compare/v0.4.3...v0.5)

**Merged pull requests:**

- Rename to chef-provisioning-docker [\#17](https://github.com/chef/chef-provisioning-docker/pull/17) ([jkeiser](https://github.com/jkeiser))

## [v0.4.3](https://github.com/chef/chef-provisioning-docker/tree/v0.4.3) (2014-10-06)
[Full Changelog](https://github.com/chef/chef-provisioning-docker/compare/v0.4.2...v0.4.3)

**Closed issues:**

- Publishing ports [\#10](https://github.com/chef/chef-provisioning-docker/issues/10)

**Merged pull requests:**

- added the option to use 2 different ports \#10 [\#12](https://github.com/chef/chef-provisioning-docker/pull/12) ([matiasdecarli](https://github.com/matiasdecarli))

## [v0.4.2](https://github.com/chef/chef-provisioning-docker/tree/v0.4.2) (2014-09-23)
[Full Changelog](https://github.com/chef/chef-provisioning-docker/compare/v0.4.1...v0.4.2)

**Fixed bugs:**

- superclass mismatch for class DockerContainer [\#6](https://github.com/chef/chef-provisioning-docker/issues/6)

**Closed issues:**

- Enable to provisoning a container [\#8](https://github.com/chef/chef-provisioning-docker/issues/8)

## [v0.4.1](https://github.com/chef/chef-provisioning-docker/tree/v0.4.1) (2014-08-20)
[Full Changelog](https://github.com/chef/chef-provisioning-docker/compare/v0.4.0...v0.4.1)

## [v0.4.0](https://github.com/chef/chef-provisioning-docker/tree/v0.4.0) (2014-08-19)
[Full Changelog](https://github.com/chef/chef-provisioning-docker/compare/v0.2...v0.4.0)

**Merged pull requests:**

- Cleanup URL parsing and support remote Docker API endpoints [\#4](https://github.com/chef/chef-provisioning-docker/pull/4) ([johnewart](https://github.com/johnewart))
- Machine image support along with the new driver API  [\#3](https://github.com/chef/chef-provisioning-docker/pull/3) ([johnewart](https://github.com/johnewart))

## [v0.2](https://github.com/chef/chef-provisioning-docker/tree/v0.2) (2014-04-14)
[Full Changelog](https://github.com/chef/chef-provisioning-docker/compare/v0.1.1...v0.2)

## [v0.1.1](https://github.com/chef/chef-provisioning-docker/tree/v0.1.1) (2014-04-12)
[Full Changelog](https://github.com/chef/chef-provisioning-docker/compare/v0.1...v0.1.1)

## [v0.1](https://github.com/chef/chef-provisioning-docker/tree/v0.1) (2014-04-11)


\* *This Change Log was automatically generated by [github_changelog_generator](https://github.com/skywinder/Github-Changelog-Generator)*