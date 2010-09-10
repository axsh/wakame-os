require 'rubygems'
require 'clios'

module WakameOS
  module Client
    class Event < SetupBase

      def self.setup(option={})
        hash = super(option)
        remote = Remote.new(hash, option)
        return remote
      end

      class Remote
        include Logger

        attr_reader :prefix, :option
        def initialize(params, option)
          @mutex  = Monitor.new
          @prefix = (option.delete(:prefix)        || 'wakame.user.event'             )+'.'
          @name   = (params[:credential].hash.to_s || WakameOS::Utility::UniqueKey.new)+'.'
          @option = option
        end

        def observe(event_name, &blk)
          @mutex.synchronize {
            amqp = WakameOS::Client::Environment.create_amqp_client
            amqp.start
            logger.info "observing queue: #{@prefix+@name+event_name}"
            amqp.queue(@prefix+@name+event_name, :auto_delete => true, :exclusive => false).subscribe { |message|
              event = ::Marshal.load(message[:payload])
              blk.call(event)
            }
            amqp.stop
          }
        end

        def notify(event_name, event)
          @mutex.synchronize {
            amqp = WakameOS::Client::Environment.create_amqp_client
            amqp.start
            logger.info "publish to queue: #{@prefix+@name+event_name}"
            amqp.queue(@prefix+@name+event_name, :auto_delete => true, :exclusive => false).publish(::Marshal.dump(event))
            amqp.stop
          }
        end
      end

    end
  end
end
