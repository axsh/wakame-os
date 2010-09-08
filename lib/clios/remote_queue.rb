#
require 'clios'

module WakameOS
  module Client
    class Queue < SetupBase

      def self.setup(option={})
        hash = super(option)
        remote = Remote.new(option)
        return remote
      end

      class Remote
        attr_reader :prefix, :option
        def initialize(option)
          @mutex  = Monitor.new
          @prefix = option.delete(:prefix) || 'wakame.user.queue.'
          @name   = option.delete(:name  ) || WakameOS::Utility::UniqueKey.new
          @option = option
          @bunny_option = { :spec => '08' } # TODO: other server

          WakameOS::Client::SystemCall.instance.add_gc_target_queues(@prefix+@name)

        end

        def finalize
          amqp = WakameOS::Client::Environment.create_amqp_client
          amqp.start
          amqp.queue(@prefix+@name, :auto_delete => true, :exclusive => false).delete
          amqp.stop

          WakameOS::Client::SystemCall.instance.remove_gc_target_queues(@prefix+@name)
        end

        def push(object)
          amqp = WakameOS::Client::Environment.create_amqp_client
          amqp.start
          amqp.queue(@prefix+@name, :auto_delete => true, :exclusive => false).publish(::Marshal.dump(object))
          amqp.stop
        end

        def pop(wait=true)
          amqp = WakameOS::Client::Environment.create_amqp_client
          amqp.start
          queue = amqp.queue(@prefix+@name, :auto_delete => true, :exclusive => false)
          begin
            data = queue.pop
            loop_flag = (data[:payload]==:queue_empty)
            sleep 0.1 if loop_flag # TODO: lazy...
          end while loop_flag
          ret = ::Marshal.load(data[:payload])
          amqp.stop
          ret
        end
        
      end
    end
  end
end

      
