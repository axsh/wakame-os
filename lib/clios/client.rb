#
require 'clios'

require 'monitor'

#
module WakameOS
  module Client
    class SystemCall

      # Class Methods
      @@instance = nil
      def self.setup
        raise AlreadySetup.new if @@instance
        @@instance = self.new
        @@instance.connect
        @@instance
      end
      def self.teardown
        raise AlreadyTeardown.new unless @@instance
        @@instance.disconnect
        @@instance = nil
      end
      def self.instance
        self.setup unless @@instance
        @@instance
      end
      
      class AlreadySetup < Exception; end
      class AlreadyTeardown < Exception; end
      
      # Instance Methods
      def initialize
        @mutex = Monitor.new
        @gc_target_queues = {}
      end

      def connect
        @mutex.synchronize {
          @amqp = WakameOS::Client::Environment.create_amqp_client
          @amqp.start
        }
      end
      
      def add_gc_target_queues(queue_names)
        @mutex.synchronize {
          queue_names.each do |queue_name|
            @gc_target_queues[queue_name] = true
          end
        }
      end

      def remove_gc_target_queues(queue_names)
        @mutex.synchronize {
          queue_names.each do |queue_name|
            @gc_target_queues.delete(queue_name)
          end
        }
      end

      def disconnect
        @mutex.synchronize {
          @gc_target_queues.keys.each do |queue_name|
            begin
              @amqp.queue(queue_name, :auto_delete => true).delete
            rescue => e
              # ingore any exception
            end
          end
          @amqp.stop
        }
      end    
    end
  end
end
