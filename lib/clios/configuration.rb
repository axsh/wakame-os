#
require 'ostruct'

#
module WakameOS
  class Configuration

    def self.default_server
      {
        :amqp_server => 'localhost',
        :daemonize => false,
      }
    end

    def self.cloud_catalog(&blk)
      @@config ||= Global.new
      blk.call(@@config) if block_given?
      @@config
    end
    
    class Global
      def initialize
        @credential = {}
        @spec       = {}
        @spec_alias = {}
      end
      
      def credential(name, &blk)
        @credential[name] ||= Credential.new
        blk.call(@credential[name]) if block_given?
        @credential[name]
      end
      
      def spec(name, &blk)
        if block_given?
          @spec[name] ||= Specification.new
          blk.call(@spec[name])
        else
          yet_another = @spec_alias[name]
          searched = @spec[yet_another || name]
          searched
        end
      end
      
      def spec_alias(name, aka)
        @spec_alias[name] = aka
      end
    end
    
    class Credential < OpenStruct; end
    
    class Specification
      
      attr_accessor :credential, :driver
      attr_reader :life_circle_pattern
      
      def initialize
        @credential          = nil
        @driver              = 'localhost'
        @life_circle_pattern = :adhoc
        @life_time           = nil
        @requirement         = nil
      end
      
      def requirement(&blk)
        @requirement ||= Requirement.new
        blk.call(@requirement) if block_given?
        @requirement
      end

      def life_circle_pattern=(pattern_name)
        case pattern_name
        when :permanent
        when :adhoc
        else
          raise ConfigurationError.new('Parameter "life_circle_pattern" does not have a value: '+pattern_name.inspect)
        end
      end

      def life_time(&blk)
        @life_time ||= LifeTime.new
        blk.call(@life_time) if block_given?
        @life_time
      end
      
      class Requirement < OpenStruct; end
      class LifeTime < OpenStruct; end

    end
    
    class ConfigurationError < Exception; end
  end
end
