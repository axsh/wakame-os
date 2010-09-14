#
require 'rubygems'
require 'wakame'

credential = Wakame::Environment.os_user_credential

rpc = Wakame::SyncRpc.new('instance')

threads = []
20.times {
  threads << Thread.start {
     p rpc.create_instances(credential, 'unknown')
  }
}
threads.each do |thread|
  thread.join
end

print rpc.list_instances.inspect




