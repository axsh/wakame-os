require 'rubygems'
require 'clios'
require 'util'

require 'thread'
require 'monitor'

require 'bunny'
# require 'carrot'

module WakameOS
  module Client
    class Process < SetupBase

      def self.setup(option={})
        hash              = super(option)
        remote            = Remote.new(option)
        remote.credential = hash[:credential]
        remote.spec_name  = hash[:spec_name]
        return remote
      end
      
      def self.fork(*argv, &block)
        setup.fork(*argv, &block)
      end
      
      class Remote
        include Logger
        attr_accessor :credential, :spec_name, :option
        def initialize(option)
          @mutex = Monitor.new
          @instance = WakameOS::Client::SyncRpc.new('instance')
          @agent = WakameOS::Client::SyncRpc.new('agent')
          @option = option
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

          amqp = Bunny.new(option)
          amqp.start

          gc_targets = []
          logger.info "Making a code queue."
          response_queue_name = nil
          gc_targets << request_queue_name  = "wakame.remote.request-#{WakameOS::Utility::UniqueKey.new}"
          gc_targets << response_queue_name = "wakame.remote.response-#{WakameOS::Utility::UniqueKey.new}" if need_response
          WakameOS::Client::SystemCall.instance.add_gc_target_queues(gc_targets)
          request_queue  = amqp.queue(request_queue_name,  :auto_delete => true)
          response_queue = amqp.queue(response_queue_name, :auto_delete => true) if need_response

          request_queue.publish(::Marshal.dump(job))
          logger.info "Insert a job request into the queue."
          response = @agent.process_jobs(@credential,
                                         [{:request => request_queue_name, :response => response_queue_name}],
                                         @spec_name)
          logger.info "Response: " + response.inspect
          
          queue_count = response[:queue_count] || 0
          if response[:waiting_agents].size < queue_count
            logger.info "New instance is required."
            @instance.create_instances(@credential, @spec_name)
          end
          logger.info "done the request."
          
          if need_response
            item = nil
            need_loop = true
            begin 
              item = response_queue.pop
              logger.info "RESPONSE (MARSHAL): " + item.inspect
              if need_loop = (item[:payload]==:queue_empty)
                sleep 0.5 # TODO: lazy wait
              end
            end while need_loop
            result = ::Marshal.load(item[:payload])
            logger.info "RESPONSE #{response_queue_name} (OBJECT): " + result.inspect
            response_queue.delete
          end

          WakameOS::Client::SystemCall.instance.remove_gc_target_queues(gc_targets)
          amqp.stop
          result
        end
        protected :_execute

    end
      
    end
  end
end
