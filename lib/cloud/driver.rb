#
require 'rubygems'
require 'util'

require 'thread'
require 'monitor'
#
module WakameOS
  module Cloud

    class Driver
      include Logger
      @@driver_create_mutex = Monitor.new
      def self.create(provider_name, config)
        ret = nil
        @@driver_create_mutex.synchronize {
          provider_name = (provider_name == 'aws')? 'AWS' : provider_name.camel_case # :-(
          logger.info "setup driver for provider named \"#{provider_name}\" with config."
          eval_string = provider_name.to_s + '.new(config)'
          ret = eval(eval_string)
        }
        ret
      end
    end

    class Instance
      class Status
        def initialize(code, name)
          @code = code
          @name = name
        end
        def to_s
          @name
        end
        UNKNOWN = Status.new(0, 'unknown')
        PENDING = Status.new(1, 'pending')
        RUNNING = Status.new(2, 'running')
        REBOOTING = Status.new(3, 'rebooting')
        SHUTTING_DOWN = Status.new(4, 'shutting down')
        TERMINATED = Status.new(5, 'terminated')
        ACCIDENTAL = Status.new(6, 'accidental')
      end

      attr_accessor :provider, :global_name, :local_name, :state, :public_ips, :private_ips
      attr_accessor :create_on, :update_on, :extra_information

      attr_reader :driver
      def initialize(driver)
        @provider = 'UNKNOWN'
        @global_name = 'UNKNOWN'
        @local_name = 'UNKNOWN'
        @state = Status::UNKNOWN
        @public_ips = []
        @private_ips = []

        @create_on = DateTime.now
        @update_on = DateTime.now

        @extra_information = {}

        @driver = driver
      end

      def touch
        @update_on = DateTime.now
      end

      def inspect
        "<Instance: Provider=#{@provider}, GlobalName=#{@global_name}, LocalName=#{@local_name}, State=#{@state}, PublicIPs=#{@public_ips}, PrivateIPs=#{@private_ips}>"
      end
    end

    # TODO: imprement cloud details more
    class InstanceLocation
      # name, country, region, zone, ...
    end

    class InstanceSpecification
      # name, ram, disk, bandwidth, price, ...
    end

    class InstanceAuthentication
      # should be inherited to SSH, or Password...
    end
    
    class MachineImage
      # name, type, size
    end

  end
end
