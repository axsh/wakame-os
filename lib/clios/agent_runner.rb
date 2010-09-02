#
# require 'daemonize'
require 'util'
require "optparse"

# entry point
module WakameOS
  module Runner
    
    class Agent
      def self.start(*argv)
        puts 'Wakame-OS Agent (CLIOS - Cluster Level Infrastructure Operation System)'
        puts 'Copyright (C) Wakame Software Fundation.'
        
        boot_token = "UNKNOWN.#{WakameOS::Utility::UniqueKey.new}"
        config = WakameOS::Configuration.default_server
        opts = OptionParser.new
        
        # Options
        opts.on('-v', '--version'){
          puts 'Version ' + WakameOS::VERSION.to_s
          config[:require_exit] = true
        }
        opts.on('-X', '--undaemonize'){
          config[:daemonize] = false
        }
        
        opts.on("-t", "--token TOKEN", String ){|_boot_token|
          config[:boot_token] = _boot_token
          boot_token = _boot_token
        }
        
        opts.parse!(argv[0])
        exit(1) if config[:require_exit]
        # Process.daemon if Process.respond_to?(:daemon) && !config[:daemonize]
        
        puts 'Token(boot_token or global_name) = "'+boot_token.to_s+'"'
        
        server = WakameOS::Server.new
        agent = WakameOS::Agent.new(boot_token)
        server.start(config, agent.context)
      end
    end

  end
end
