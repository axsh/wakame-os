require 'rubygems'
require 'util'

require 'thread'
require 'monitor'

require 'bunny'
# require 'carrot'

module WakameOS
  module Client
    class Process
      @@credential = {}
      @@spec_name  = 'default'
      @@option     = {}
      
      def self.credential;              @@credential;                  end
      def self.credential=(credential); @@credential = credential.dup; end
      def self.spec_name;               @@spec_name;                   end
      def self.spec_name=(spec_name);   @@spec_name = spec_name.dup;   end
      
      def self.setup(option={})
        credential = option.delete(:credential) || @@credential
        spec_name  = option.delete(:spec_name)  || @@spec_name  || 'default'
        
        option = option.dup.merge({:spec => '08'})
        remote = Remote.new(option)
        @@credential = remote.credential = credential.dup
        @@spec_name  = remote.spec_name  = spec_name.dup
        @@option     = remote.option     = option
        return remote
      end
      
      def self.fork(*argv, &block)
        setup.fork(*argv, &block)
      end
      
      class Remote
        attr_accessor :credential, :spec_name, :option
        def initialize(option)
          # @amqp = Carrot.new(option)
          @amqp = Bunny.new(option)
          @amqp.start

          @mutex = Monitor.new
          @instance = WakameOS::Client::SyncRpc.new('instance')
          @agent = WakameOS::Client::SyncRpc.new('agent')
        end

        def fork(*argv, &block)
          # TODO: Check the arity
          @mutex.synchronize {
            _execute(WakameOS::Utility::Job::RubyProc.new({
                                                            :code => WakameOS::Utility::ProcSerializer.dump({}, &block),
                                                            :argv => argv,
                                                          }))
          }
        end

        def fork_join(*argv, &block)
          result = nil

          # TODO: Check the arity
          @mutex.synchronize {
            result = _execute(WakameOS::Utility::Job::RubyProc.new({
                                                                     :code => WakameOS::Utility::ProcSerializer.dump({}, &block),
                                                                     :argv => argv,
                                                                   }), true)
          }
          result
        end

        def eval(ruby_code)
          result = nil
          @mutex.synchronize {
            result = _execute(WakameOS::Utility::Job::RubyPlainCode.new({
                                                                 :code => ruby_code,
                                                               }), true)
          }
          result
        end
        
        def _execute(job, need_response=false)
          result = nil

          print "Making a code queue.\n"
          request_queue_name  = "#{job.class.name}.Request-#{WakameOS::Utility::UniqueKey.new}"
          request_queue  = @amqp.queue(request_queue_name,  :auto_delete => true)
          response_queue_name = "#{job.class.name}.Response-#{WakameOS::Utility::UniqueKey.new}"
          response_queue = @amqp.queue(response_queue_name, :auto_delete => true)

          request_queue.publish(::Marshal.dump(job))
          print "Insert a job request into the queue.\n"
          response = @agent.process_jobs(@credential,
                                         [{:request => request_queue_name, :response => response_queue_name}],
                                         @spec_name)
          print "Response: " + response.inspect + "\n"
          
          queue_count = response[:queue_count] || 0
          if response[:waiting_agents].size < queue_count
            print "New instance is required.\n"
            @instance.create_instances(@credential, @spec_name)
          end
          print "done the request.\n"
          
          if need_response
            item = nil
            need_loop = true
            begin 
              item = response_queue.pop
              print "RESPONSE (MARSHAL): " + item.inspect + "\n"
              if need_loop = (item[:payload]==:queue_empty)
                sleep 0.5 # TODO: lazy wait
              end
            end while need_loop
            result = ::Marshal.load(item[:payload])
            print "RESPONSE #{response_queue_name} (OBJECT): " + result.inspect + "\n"
          end
          response_queue.delete

          result
        end
        protected :_execute

    end
      
    end
  end
end
