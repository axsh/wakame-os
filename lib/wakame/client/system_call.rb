#
require 'thread'

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
        @@instance
      end
      
      class AlreadySetup < Exception; end
      class AlreadyTeardown < Exception; end
      
      # Instance Methods
      def initialize
      end
      def connect
      end
      
      def disconnect
      end    
    end
  end
end
