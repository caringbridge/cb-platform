#
# Cookbook Name:: cb-platform
# Recipe:: default
#
# Copyright (C) 2014 Wyatt Andersen
#
# All rights reserved - Do Not Redistribute
#

#
# Cookbook Name:: cb-platform
# Recipe:: default
#
# Copyright (c) 2014, CaringBridge, a nonprofit organization
#
# All rights reserved - Do Not Redistribute

include_recipe "yum"
include_recipe "yum-epel"
include_recipe "python"

# Create the hosts file at /etc/hosts
hostsfile_entry node['cbplatform']['server']['ip_address'] do
  hostname node['cbplatform']['server']['fqdn']
  aliases node['cbplatform']['server']['aliases']
end

# Modify PHP Settings
cookbook_file "caringbridge.ini" do
  path "/usr/local/zend/etc/conf.d/caringbridge.ini"
  action :create
  notifies :restart, 'service[zend-server]'
end

ENV['APPLICATION_ENV'] = 'vagrant-cluster'

# Create vhost if necessary
cmd = [
  '/usr/local/zend/bin/php /opt/platform/scripts/cb vhost',
  '/etc/httpd/conf.d/vhost-platform.conf',
].join(' > ')
execute cmd do
  cwd node['cbplatform']['project_path']
  env 'APPLICATION_ENV' => 'vagrant-cluster'
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
file '/etc/httpd/conf.d/ssl.conf' do
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

# Hacky Create Cron Jobs
cookbook_file "cb_cron" do  
    user "root" 
    path "/var/spool/cron/root"
    action :create
end

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