# Cloud Catalog - Server Configuration Detail
require 'clios'
WakameOS::Configuration.cloud_catalog do |cc|

  ## This configuration is to define some logical name of server type.
  ## You can pick servers up from any IaaS Clouds if you have a driver.
  #
  # require 'wakame'
  # rpc = WakameOS::Client::SyncRpc('instance')
  # rpc.create_instances(credential, logical_name)


  ####################
  # Credential Section

  cc.credential 'amazon_account' do |c|
    c.access_key        = ''
    c.secret_access_key = ''
  end

  cc.credential 'wakame_account' do |c|
    c.user     = ''
    c.password = ''
  end

  ######################
  # Server Specification
  
  cc.spec_alias 'default',   'public'
  cc.spec_alias 'unknown', 'private_permanent_host'

  cc.spec 'public' do |s|
    s.credential = 'amazon_account'
    s.driver = 'aws'
    s.life_time do |lt|
        lt.running = 60
    end
    s.requirement do |r|
      r.instance_type = 't1.micro'
      r.image_id = 'ami-84db39ed'
    end
  end

  cc.spec 'private' do |s|
    s.credential = 'wakame_account'
    s.driver = 'wakame'
  end

  cc.spec 'private_permanent_host' do |s|
    s.driver = 'permanent_host'
    s.life_circle_pattern = :permanent
    s.life_time do |lt|
      lt.running    = 60
      lt.terminated = 30
    end
  end

end

# if your cloud credential must be separated from this file for security reason, 
# please wrote your own credential file.
# secure_section.rb will be loaded automaticaly.
#
begin
  require File.expand_path('../secure_section', __FILE__)
rescue LoadError => e
  # No load, No secure.
end
#
# ---[secure_section.rb]---
# require 'clios'
# WakameOS::Configuration.cloud_catalog do |cc|
#
#   cc.credential 'amazon_account' do |c|
#     c.access_key        = ''
#     c.secret_access_key = ''
#  end
#
# end

