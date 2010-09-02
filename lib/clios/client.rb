#
require 'rubygems'
require 'mq'

require 'bunny'
# require 'carrot'

require 'thread'
require 'monitor'

#
module WakameOS
  module Client
    class AsyncRpc
      def initialize(queue_name, mq=nil)
        @callbacks = {}
        @mq = mq || MQ.new
        @remote = mq.queue(queue_name)

        # TODO: make it unique
        @name = "Wakame-AsyncRpc-Response-ID.#{WakameOS::Utility::UniqueKey.new}"
        response = @mq.queue(@name, :auto_delete => true).subscribe{|info, msg|
          if callback = @callbacks.delete(info.message_id)
            callback.call ::Marshal.load(msg)
          end
        }

        @monitor = Monitor.new
      end

      def method_missing(method, *args, &blk)
        # TODO: How to make sync with return
        # TODO: make it unique
        message_id = "random message id #{WakameOS::Utility::UniqueKey.new}"
        @monitor.synchronize {
          @callbacks[message_id] = blk if blk
          @remote.publish(::Marshal.dump([method, *args]), :reply_to => blk ? @name : nil, :message_id => message_id)
        }
        true
      end
    end

    class SyncRpc
      def initialize(queue_name)
        
        # @amqp = Carrot.new()
        @amqp = Bunny.new(:spec => '08')
        @amqp.start

        @rabbit_mutex = Monitor.new
        @queue_monitor = Monitor.new

        @remote = @amqp.queue(queue_name, :auto_delete => true)

      end

      def method_missing(method, *args, &blk)
        response = nil
        response_id = "Wakame-SyncRpc-Response-ID.#{WakameOS::Utility::UniqueKey.new}"
        @rabbit_mutex.synchronize {
          response = @amqp.queue(response_id, :auto_delete => true)
        }
        message_id = "random message id #{WakameOS::Utility::UniqueKey.new}"
        @queue_monitor.synchronize {
          @remote.publish(::Marshal.dump([method, *args]), :reply_to => response_id, :message_id => message_id)
        }

        still_watch = false
        begin
          package = response.pop()
          sleep 0.1 if still_watch = (package[:payload]==:queue_empty)
        end while still_watch # TODO: fix a lazy code...
        response.delete

        ret = ::Marshal.load(package[:payload])

        blk.call(ret) if blk
        raise ret if ret.class.ancestors.include? Exception
        ret
      end
    end
    
  end
end
