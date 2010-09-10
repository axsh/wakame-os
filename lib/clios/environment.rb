require 'clios'

require 'rubygems'
require 'bunny'

module WakameOS
  module Client
    class Environment
      
      @@env = nil 
      
      def self.init(option={})
        @@env = {
          :os_server            => ENV['WAKAME_OS_SERVER']            || 'localhost',
          :os_user              => ENV['USER']                        || 'wakame',
          :os_secret_key        => ENV['WAKAME_OS_SECRET_KEY']        || '',
          :os_default_spec_name => ENV['WAKAME_OS_DEFAULT_SPEC_NAME'] || 'default',
        }.merge(option)
      end

      def self.value(name)
        init unless @@env
        @@env[name]
      end

      def self.os_user_credential
        init unless @@env
        {
          :user => @@env[:os_user],
          :secret_key => @@env[:os_secret_key],
        }
      end

      def self.create_amqp_client
        init unless @@env
        return Bunny.new(:spec => '08', :host => self.os_server)
      end

      def self.method_missing(method, *argv, &block)
        raise NoMethodError.new if block_given? 
        init unless @@env

        ret = nil
        if method.to_s.match(/.*=$/)
          raise NoMethodError.new unless argv.size==1
          ret = @@env[(method.to_s.split('='))[0].to_sym] = argv[0]
        else
          raise NoMethodError.new unless argv.size==0
          ret = @@env[method]
        end
        ret
      end

    end
  end
end
