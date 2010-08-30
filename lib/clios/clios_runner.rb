#
# require 'daemonize'
require "optparse"

# entry point
module WakameOS
  module Runner
    
    class Clios
      def self.start(*argv)
        puts 'Wakame-OS (CLIOS - Cluster Level Infrastructure Operation System)'
        puts 'Copyright (C) Wakame Software Fundation.'
        
        config = WakameOS::Configuration.default_server
        opts = OptionParser.new
        
        # Options
        opts.on( '-v', '--version' ) {
          puts 'Version ' + WakameOS::VERSION.to_s
          config[:require_exit] = true
        }
        opts.on( '-X', '--undaemonize' ) {
          config[:daemonize] = false
        }
        
        opts.parse!(argv[0])
        exit(1) if config[:require_exit]
        # Process.daemon if Process.respond_to?(:daemon) && !config[:daemonize]
        
        server = WakameOS::Server.new
        system_call = WakameOS::SystemCall.new
        server.start(config, system_call.context)
      end
    end

  end
end
