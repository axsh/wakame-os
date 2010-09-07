#
require 'clios'

require 'rubygems'
require 'eventmachine'
require 'amqp'

#
module WakameOS
  class Server
    include Logger

    def self.start(config, context)
      self.new.start(config, context)
    end

    def start(config, context)

      config ||= WakameOS::Configuration.default_server

      Signal.trap(:INT) {
        # TODO: flush every thing.
        logger.info "Shutting down..."
        AMQP.stop { EM.stop }
        exit(1)
      }

      AMQP.start(:host => config[:amqp_server]) { # TODO: other parameters
        
        mq ||= MQ.new

        context.rpc_procs.each { |name, proc_object, blk|
          logger.info "Register: \"wakame.rpc.#{name.to_s}\" as proc."
          blk.call(mq, 'wakame.rpc.'+name, proc_object)
        }

        context.rpc_classes.each { |name, klass, blk|
          logger.info "Register: \"wakame.rpc.#{name.to_s}\" as #{klass.class.name.to_s}"
          blk.call(mq, 'wakame.rpc.'+name, klass)
        }

      }
      
    end
  end
end

