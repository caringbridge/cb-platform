#
# Cookbook Name:: cb-platform
# Recipe:: default
#
# Copyright (C) 2014 YOUR_NAME
#
# All rights reserved - Do Not Redistribute
#

#
# Cookbook Name:: platform
# Recipe:: default
#
# Copyright (c) 2014, CaringBridge, a nonprofit organization
#
# All rights reserved - Do Not Redistribute

include_recipe "yum"
include_recipe "yum-epel"
include_recipe "python"
# include_recipe "role-zendserver"
# include_recipe "role-mongodb-mongos"
# include_recipe "role-rabbitmq"
# include_recipe "role-sphinx"
# include_recipe "role-twemcache"

puts 'DOING THE GOOD STUFF HERE!!!!!!!!'

# Create the hosts file at /etc/hosts
hostsfile_entry node['cbplatform']['server']['ip_address'] do
  hostname node['cbplatform']['server']['fqdn']
  aliases node['cbplatform']['server']['aliases']
end

# # Hacky Enable PHP Extensions
# ["mongo.ini", "memcached.ini", "pdo_dblib.ini"].each do |ext|
#   cookbook_file ext do
#     path "/usr/local/zend/etc/conf.d/" + ext
#     action :create
#     notifies :restart, 'service[zend-server]'
#   end
# end

# Modify PHP Settings
cookbook_file "caringbridge.ini" do
  path "/usr/local/zend/etc/conf.d/caringbridge.ini"
  action :create
  notifies :restart, 'service[zend-server]'
end

# Create vhost if necessary
cmd = [
  '/usr/local/zend/bin/php /opt/platform/scripts/cb vhost',
  '/etc/httpd/conf.d/vhost-platform.conf',
].join(' > ')
execute cmd do
  cwd node['cbplatform']['project_path']
  env 'APPLICATION_ENV' => 'vagrant'
  user 'root'
  group 'root'
  not_if { ::File.exists?('/etc/httpd/conf.d/vhost-platform.conf') }
  notifies :restart, 'service[zend-server]'
end

# Handle Self-signed SSL Certificates
# @todo: Right we should be using non-sensative keys that
# can be stored in the cb-platform repo
directory "/etc/httpd/conf/ssl" do
  owner "root"
  group "root"
  mode 0755
  action :create
end
file "/etc/httpd/conf/ssl/server.key" do
  content ::File.open("/opt/platform/chef/cookbooks/cbplatform/files/default/server.key").read
  owner 'root'
  group 'root'
  mode 0755  
  action :create
end
file "/etc/httpd/conf/ssl/server.crt" do
  content ::File.open("/opt/platform/chef/cookbooks/cbplatform/files/default/server.crt").read
  owner 'root'
  group 'root'
  mode 0755  
  action :create
end
file '/etc/httpd/conf/ssl/ssl.conf' do
  content ::File.open("/opt/platform/chef/cookbooks/cbplatform/files/default/ssl.conf").read
  owner 'root'
  group 'root'
  mode 0777  
  action :create
  notifies :restart, 'service[zend-server]'
end

# Manage vagrant.conf
cookbook_file 'vagrant.conf' do
  path "/etc/httpd/conf.d/vagrant.conf"
  action :create
  notifies :restart, 'service[zend-server]'
end

# # Install supervisor.d to manage RabbitMQ workers
# cookbook_file 'supervisor.conf' do
#   path '/etc/supervisor.conf'
#   action :create
# end
# cookbook_file 'supervisor-init' do
#   path '/etc/init.d/supervisor'
#   mode 0755
#   action :create
# end
# python_pip "supervisor" do
#   action :install
# end

# # Stephen's udev hack
# # Please tell me there's an easier way to do what we're about to do here.
# # See: http://razius.com/articles/launching-services-after-vagrant-mount/
# if node['cbplatform']['environment'] == 'vagrant'
#   # The init.d runlevels won't start Zend Server at the correct time, so just
#   # disable the service. We'll start it with a udev rule when the filesystems
#   # finish mounting.
#   service 'zend-server' do
#     action :disable
#   end
#
#   # I don't know if screen is necessary. It's used in the example at the URL
#   # above and it certainly isn't hurting anything.
#   yum_package 'screen' do
#     action :install
#   end
#
#   # This file contains the udev rule that starts Zend Server when VirtualBox's
#   # shared folder filesystems finish mounting.
#   cookbook_file 'vagrant-apache-udev-rules' do
#     path '/etc/udev/rules.d/50-vagrant-mount.rules'
#     action :create
#     notifies :restart, 'service[zend-server]'
#   end
# end

# Create dirs outside of source control
["/public/assets/ugc", "/public/assets/ugc/pdf", "/logs"].each do |dir|
  directory node['cbplatform']['project_path'] + dir do
    owner "apache"
    group "apache"
    mode 0755
    action :create
    notifies :restart, 'service[zend-server]'
  end
end

# # Turn on searchd
# script "searchd_on" do
#   interpreter "bash"
#   user "root"
#   cwd "/sbin"
#   code <<-EOH
#   chkconfig searchd on
#   EOH
# end

# Symbolic Link zend php and php
script "symlink_php" do
  interpreter "bash"
  user "root"
  cwd "/sbin"
  code <<-EOH
  ln -s /usr/local/zend/bin/php /usr/bin/php
  EOH
  not_if '/usr/bin/php'
end

# @todo: This doesn't work, why not?
# link "/usr/local/zend/bin/php" do
#   to "/usr/bin/php"
# end

# # Symbolic Link zend php and php
# script "sphinx_start" do
#   interpreter "bash"
#   user "root"
#   cwd "/sbin"
#   code <<-EOH
#   sudo env APPLICATION_ENV=vagrant /opt/platform/scripts/cb search start
#   EOH
# end

# Hacky Create Cron Jobs
cookbook_file "cb_cron" do
  user "root"
  path "/var/spool/cron/root"
  action :create
end
