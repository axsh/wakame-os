require 'clios'
require 'util'

require 'rubygems'
require 'bunny'

module WakameOS
  module Client
    class Environment
      
      @@env = nil 
      
      def self.init(option={})
        @@env = {
          :os_server            => ENV['WAKAME_OS_SERVER']            || 'localhost',
          :os_server_port       => ENV['WAKAME_OS_PORT']              || 5672,
          :os_user              => ENV['USER']                        || 'wakame',
          :os_secret_key        => ENV['WAKAME_OS_SECRET_KEY']        || nil,
          :os_default_spec_name => ENV['WAKAME_OS_DEFAULT_SPEC_NAME'] || 'default',
          :os_instance_name     => ENV['WAKAME_OS_INSTANCE_NAME']     || nil,
          :os_boot_token        => ENV['WAKAME_OS_BOOT_TOKEN']        || WakameOS::Utility::UniqueKey.new,
          :os_job_id            => ENV['WAKAME_OS_JOB_ID']            || nil,
        }.merge(option)
      end

      def self.value(name)
        init unless @@env
        @@env[name]
      end

      def self.os_user_credential
        init unless @@env
        {
          :user              => @@env[:os_user],
          :secret_key        => @@env[:os_secret_key],
          :instance_name     => @@env[:os_instance_name],
          :boot_token        => @@env[:os_boot_token],
          :job_id            => @@env[:os_job_id],
        }
      end

      def self.create_amqp_client
        init unless @@env
        return Bunny.new(:spec => '08', :host => self.os_server, :port => self.os_server_port)
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
