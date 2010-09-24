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
          @mutex     = Monitor.new
          @prefix    = (option.delete(:prefix)      || 'wakame.user.event'             )+'.'
          credential =  params[:credential]         || { :user => WakameOS::Utility::UniqueKey.new }
          @name      = (credential[:user].hash.to_s || WakameOS::Utility::UniqueKey.new)+'.'
          @option    =  option
        end

        def observe(event_name, &blk)
          Observer.new {
            amqp = Environment.create_amqp_client
            amqp.start
            logger.debug "observing queue: #{@prefix+@name+event_name}"
            amqp.queue(@prefix+@name+event_name, :auto_delete => true, :exclusive => false).subscribe { |message|
              event = ::Marshal.load(message[:payload])
              blk.call(event)
            }
            amqp.stop
          }
        end

        def notify(event_name, event)
          @mutex.synchronize {
            amqp = Environment.create_amqp_client
            amqp.start
            logger.debug "publish to queue: #{@prefix+@name+event_name}"
            amqp.queue(@prefix+@name+event_name, :auto_delete => true, :exclusive => false).publish(::Marshal.dump(event))
            amqp.stop
          }
        end

        class Observer
          def initialize(&blk)
            @thread = Thread.new(&blk)
          end
          def stop
            Thread.kill(@thread)
          end
        end

      end

    end
  end
end
