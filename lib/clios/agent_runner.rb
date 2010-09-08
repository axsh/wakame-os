#
# require 'daemonize'
require 'util'
require "optparse"

# entry point
module WakameOS
  module Runner
    
    class Agent
      include Logger
      def self.start(*argv)
        print "Wakame-OS Agent (CLIOS - Cluster Level Infrastructure Operation System)\n"
        print "Copyright (C) Wakame Software Fundation.\n"
        
        boot_token = "UNKNOWN.#{WakameOS::Utility::UniqueKey.new}"
        config = WakameOS::Configuration.default_server
        opts = OptionParser.new
        
        # Options
        opts.on('-v', '--version'){
          print "Version #{WakameOS::VERSION.to_s}\n"
          config[:require_exit] = true
        }
        opts.on('-X', '--undaemonize'){
          config[:daemonize] = false
        }
        
        opts.on("-t", "--token TOKEN", String ){|_boot_token|
          config[:boot_token] = _boot_token
          boot_token = _boot_token
        }

        opts.on("-s", "--server SERVER", String){|_server|
          config[:server] = _server
          WakameOS::Client::Environment.os_server = _server
        }
        
        opts.parse!(argv[0])
        exit(1) if config[:require_exit]
        # Process.daemon if Process.respond_to?(:daemon) && !config[:daemonize]
        
        logger.info "Token(boot_token or global_name) = \"#{boot_token.to_s}\""
        
        server = WakameOS::Server.new
        agent = WakameOS::Agent.new(boot_token)
        server.start(config, agent.context)
      end
    end

  end
end
