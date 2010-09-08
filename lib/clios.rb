# Wakame-OS (CLIOS - Cluster Level Infrastructure Operation System)
# Written by Yasuhiro Yamazaki. (y-yamazaki at axsh.net)
# Copyright (C) 2010 axsh co., LTD.
# License under GPL v2.

# require section
require 'rubygems'
require 'cloud'

# $LOAD_PATH.unshift File.expand_path('../vendor/isono/lib', __FILE__)

module WakameOS

  VERSION = '0.1'

  autoload :Logger, 'clios/logger'

  autoload :Configuration, 'clios/configuration'
  autoload :Agent,         'clios/agent'
  autoload :Server,        'clios/server'
  autoload :Service,       'clios/service'
  autoload :SystemCall,    'clios/system_call'
  
  module Runner
    autoload :Clios, 'clios/clios_runner'
    autoload :Agent, 'clios/agent_runner'
  end

  module Client
    autoload :Environment, 'clios/environment'
    autoload :SetupBase,   'clios/remote'
    autoload :AsyncRpc,    'clios/rpc'
    autoload :SyncRpc,     'clios/rpc'
    autoload :Process,     'clios/remote_process'
    autoload :Queue,       'clios/remote_queue'
    autoload :SystemCall,  'clios/client'
  end

  module Utility
    autoload :ProcSerializer, 'clios/proc_serializer'
    module Job
      autoload :RubyProc,      'clios/job'
      autoload :RubyPlainCode, 'clios/job'
    end
  end

end

