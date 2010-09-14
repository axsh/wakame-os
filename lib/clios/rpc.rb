require 'clios'
require 'util'

require 'rubygems'
require 'mq'

require 'monitor'

#
module WakameOS
  module Client
    class AsyncRpc
      include Logger

      def initialize(queue_name, mq=nil)
        @callbacks = {}
        @mq = mq || MQ.new
        @remote = mq.queue('wakame.rpc.'+queue_name)

        @name = "wakame.client.response-#{WakameOS::Utility::UniqueKey.new}"
        response = @mq.queue(@name, :auto_delete => true).subscribe{|info, msg|
          if callback = @callbacks.delete(info.message_id)
            callback.call ::Marshal.load(msg)
          end
        }

        @monitor = Monitor.new
      end

      def method_missing(method, *args, &blk)
        message_id = WakameOS::Utility::UniqueKey.new
        @monitor.synchronize {
          @callbacks[message_id] = blk if blk
          @remote.publish(::Marshal.dump([method, *args]), :reply_to => blk ? @name : nil, :message_id => message_id)
        }
        true
      end
    end

    class SyncRpc
      include Logger

      def initialize(queue_name)
        @rabbit_mutex = Monitor.new
        @queue_monitor = Monitor.new
        @queue_name = queue_name

      end

      def method_missing(method, *args, &blk)
        name = 'wakame.rpc.'+@queue_name
        logger.debug "setup the client rpc channel named \"#{name}\"."
        amqp = WakameOS::Client::Environment.create_amqp_client
        amqp.start
        remote = amqp.queue(name, :auto_delete => true)
        WakameOS::Client::SystemCall.instance.add_gc_target_queues([name])
        logger.debug "entried queue name as candidation of gabage."

        response = nil
        response_id = "wakame.client.response-#{WakameOS::Utility::UniqueKey.new}"
        @rabbit_mutex.synchronize {
          response = amqp.queue(response_id, :auto_delete => true)
        }
        logger.debug "queue \"#{response_id}\" decrared."
        message_id = WakameOS::Utility::UniqueKey.new
        @queue_monitor.synchronize {
          remote.publish(::Marshal.dump([method, *args]), :reply_to => response_id, :message_id => message_id)
        }
        logger.debug "published a message which has an id \"#{message_id}\" to \"#{method.to_s}\"."

        still_watch = false
        begin
          package = response.pop()
          sleep 0.1 if still_watch = (package[:payload]==:queue_empty)
        end while still_watch # TODO: fix a lazy code...
        response.delete

        logger.debug "response: #{package.inspect}"
        ret = ::Marshal.load(package[:payload])

        blk.call(ret) if blk

        WakameOS::Client::SystemCall.instance.remove_gc_target_queues([name])
        amqp.stop
        raise ret if ret.class.ancestors.include? Exception
        ret
      end
    end
    
  end
end
