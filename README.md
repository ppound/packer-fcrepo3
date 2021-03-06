# Packer FcRepo3

<!-- [![Build Status](https://travis-ci.org/ksclarke/packer-fcrepo3.png?branch=master)](https://travis-ci.org/ksclarke/packer-fcrepo3) -->

This project contains a Packer.io build for version 3.x of the Fedora Commons Repository (fcrepo3).

[Packer.io](http://www.packer.io/) is a tool for creating identical machine images for multiple platforms from a single source configuration.  It produces images for Amazon EC2, Digital Ocean, Docker, VirtualBox, VMWare, and others.

The [Fedora Commons Repository](https://wiki.duraspace.org/display/FEDORA/All+Documentation) is a conceptual framework that uses a set of abstractions about digital information to provide the basis for software systems that can manage digital information. It provides the basis for ensuring long-term durability of the information, while making it directly available to be used in a variety of ways.

## Introduction

The first step is to [download](https://packer.io/downloads.html) and install Packer.io, making sure that its executables are on your system PATH. The next step is to build this project.

Usually a [Packer.io build](http://www.packer.io/docs/command-line/build.html) would be run with something like:

    packer build -only=amazon-ebs -var-file=vars.json fcrepo3.json

This project, though, provides a simple wrapper script. To use that, type:

    ./build.sh

or

    ./build.sh amazon-ebs

or

    ./build.sh docker

This will include the variables file, generate passwords if needed, strip the comments out of `packer-fcrepo3.json` and create `fcrepo3.json` (which is used as the build file).

Currently, only "amazon-ebs" and "docker" builds are supported. In the future, I expect to add additional support for VirtualBox (virtualbox-iso), VMWare (vmware-iso), and Digital Ocean.  Running the build script without "amazon-ebs" or "docker" will result in both being built.

If you want to run the build in debug mode, try adding the DEBUG flag to one of the above options:

    DEBUG=true ./build.sh

If you've edited the `packer-fcrepo3.json` file and want to validate the build without running it, type:

    ./build.sh validate

_Note: To have the build script use the packer-fcrepo3.json file, you'll need to have [strip-json-comments](https://github.com/sindresorhus/strip-json-comments) installed.  If you don't have that installed, the build script will use the pre-generated fcrepo3.json file. Any changes meant to persist between builds should be made to the packer-fcrepo3.json file. This requirement will be removed when Packer.io switches its configuration file format from JSON to [HCL](https://github.com/hashicorp/hcl)._

## Configuration

Before you run the build script, though, you'll need to configure a few important variables.  To get you started, the project has an `example-vars.json` file which can be copied to `vars.json` and edited.  The build script will then inject these variables into the build.  There are some variables that are general and some that are specific to a particular builder (which will only need to be supplied if you intend to use that builder).

_Note: When running the build script, any empty variable in the vars.json file that ends with `_password` will get an automatically generated value. Once a password has been automatically generated, it will continue to be refreshed with a new password at each build.  To stop this, and keep the passwords currently in the `vars.json` file, delete the `.passwords` file found in the project directory._

### General Build Variables

<dl>

  <dt>fedora_repository_name</dt>
  <dd>The public name for your Fedora repository.  Could be something as simple as "UCLA Fedora Repository".</dd>

  <dt>fedora_pid_namespace</dt>
  <dd>The default PID namespace for your Fedora repository.  Could be something as simple as "ucla".</dd>

  <dt>jvm_memory</dt>
  <dd>The amount of memory to assign to the Java Virtual Machine that runs Tomcat. It has a default value that can be overridden by this configuration option.</dd>

  <dt>jvm_max_perm_size</dt>
  <dd>The maximum amount of memory that can be used by the JVM's Permanent Generation (PermGen) space. It has a default value that can be overridden by this configuration option.</dd>

  <dt>tomcat_port</dt>
  <dd>The port at which Tomcat should run the main repository Web interface.  The default is port 80.</dd>
  
  <dt>tomcat_ssh_port</dt>
  <dd>The port at which Tomcat should run the secure repository Web interface. The default is port 443.</dd>

  <dt>packer_build_name</dt>
  <dd>A name that will distinguish your build products from someone else's. It can be a simple string like "Fedora" or "UCLA".</dd>

  <dt>keystore_config</dt>
  <dd>The configuration that should be used to initialize the SSH keystore used by Tomcat. An example pattern is available in the project's <code>example-vars.json</code> file.</dd>

  <dt>keystore_password</dt>
  <dd>The password for the SSH keystore used by Tomcat. If not supplied, the <code>build.sh</code> script will supply an automatically generated password in the fcrepo3.json file.</dd>

  <dt>fcrepo3_admin_password</dt>
  <dd>The password for the repository's 'fedoraAdmin' user. If not supplied, the <code>build.sh</code> script will supply an automatically generated password in the fcrepo3.json file.</dd>

  <dt>fcrepo3_db_password</dt>
  <dd>The password for the repository's MySQL database connection. If not supplied, the <code>build.sh</code> script will supply an automatically generated password in the fcrepo3.json file.</dd>

  <dt>mysql_root_password</dt>
  <dd>The root password for the MySQL database. If not supplied, the <code>build.sh</code> script will supply an automatically generated password in the fcrepo3.json file.</dd>

</dl>

### Non-Docker Variables

The variables below, related to ongoing software upgrades, apply to all builds _except_ Docker.  The approach with Docker is to create immutable servers.  When an upgrade of the software in your container needs to be performed, you should just spin up a new container.

Note that you do not have to opt-in for automatic upgrades for the non-Docker servers; if you don't, the system will send you an email when there is a security update that needs your attention.

<dl>
  <dt>server_admin_email</dt>
  <dd>The email address that should be configured to receive notice of available security updates.</dd>

  <dt>server_host_name</dt>
  <dd>Serves as the machine image's mail host; "localhost" is the default setting, but it can be whatever you want (e.g., a FQDN, if appropriate).</dd>

  <dt>automatic_os_security_updates</dt>
  <dd>Whether automatic security updates should be applied; the default value is "false".</dd>

  <dt>automatic_os_reboot</dt>
  <dd>If automatic security updates are applied, whether the system should be automatically rebooted afterwards (i.e., only if needed); the default value is "false".</dd>
</dl>

### Amazon-EBS Specific Variables

<dl>
  <dt>aws_access_key</dt>
  <dd>A valid AWS_ACCESS_KEY that will be used to interact with Amazon Web Services (AWS).</dd>
  <dt>aws_secret_key</dt>
  <dd>The AWS_SECRET_KEY that corresponds to the supplied AWS_ACCESS_KEY.</dd>
  <dt>aws_security_group_id</dt>
  <dd>A pre-configured AWS Security Group that will allow SSH and HTTP access to the EC2 build.</dd>
  <dt>aws_region</dt>
  <dd>The AWS region to use. For instance: <strong>us-east-1</strong> or <strong>us-west-2</strong>.</dd>
  <dt>aws_instance_type</dt>
  <dd>The AWS instance type to use. For instance: <strong>t2.medium</strong> or <strong>m3.medium</strong>.</dd>
  <dt>aws_virtualization_type</dt>
  <dd>The AWS virtualization type to use. For instance: <strong>hvm</strong> or <strong>pv</strong>.</dd>
  <dt>aws_source_ami</dt>
  <dd>The source AMI to use as a base. Note that the source AMI, virtualization type, and instance type must be <a href="http://aws.amazon.com/amazon-linux-ami/instance-type-matrix/">compatible</a>. The two tested AMIs (from 'us-east-1') are <strong>ami-0870c460</strong> (with 'pv' virtualization) and <strong>ami-0070c468</strong> (with 'hvm' virtualization). If you select another, make sure it's an Ubuntu image (as that's what the Packer.io build expects).</dd>
</dl>

### Docker Specific Variables

<dl>
  <dt>docker_user</dt>
  <dd>A Docker user (preferably a Docker registry user). Though the build is not currently configured to push to a Docker registry (like <a href="https://hub.docker.com/">Docker Hub</a>), this functionality will probably be added in the future.</dd>
</dl>

## Deployment

How you deploy the Graphite server will depend on which builder you've selected. These simple instructions assume you're already familiar with AWS and/or Docker.  For information about how to get started with these resources, consult their online documentation.

### AWS EC2 Instance

To deploy in EC2, you'll need to launch a new instance through the AWS Web Console (selecting an instance type, security group, and key pair in the process). The Packer.io build creates an AMI in your account from which the instance can be launched.

These steps will probably be automated in the future with the assistance of the AWS CLI.

### Docker

To deploy FcRepo3 in a Docker container on your local machine (after installing Docker, of course), you can type:

    docker run -p 80:80 -p 443:443 -t -i $(docker images -q | head -1) /usr/bin/supervisord -c /etc/supervisor/supervisord.conf

This should use the most recent local Docker image (i.e., the one you just created) to spin up a Docker container with ports 8080 and 8443 mapped to local ports: 80 and 443.  A secure repository connection is available at port 443 and an open one available at port 80.

You can alternatively reference it using the tag created from your docker_user, project name, and project version; for instance:

    docker run -p 80:80 -p 443:443 -t -i ksclarke/packer-fcrepo3:0.1.0 /usr/bin/supervisord -c /etc/supervisor/supervisord.conf

If you have Docker [Fig](http://www.fig.sh/) installed, you can take advantage of the project's automatically generated `fig.yml` file and just run:

    fig up

The repository will start with the correct port mappings pre-configured for you.

## Potential Gotchas

* There is an [outstanding issue](https://github.com/mitchellh/packer/issues/1752) with Docker 1.4.x and Packer's shell provisioner (which this project uses).  It works fine with Docker 1.3.3, though, so use that instead of Docker 1.4.x until the issue is resolved.
* GSearch is installed through this build, but not automagically configured yet

## License

[Apache Software License, version 2.0](LICENSE)

## Contact

If you have questions about [packer-fcrepo3](http://github.com/ksclarke/packer-fcrepo3) feel free to ask them on the FreeLibrary Projects [mailing list](https://groups.google.com/forum/#!forum/freelibrary-projects); or, if you encounter a problem, please feel free to [open an issue](https://github.com/ksclarke/packer-fcrepo3/issues "GitHub Issue Queue") in the project's issue queue.
