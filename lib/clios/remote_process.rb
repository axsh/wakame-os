require 'rubygems'
require 'clios'
require 'util'

require 'thread'
require 'monitor'

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
          result = nil

          # TODO: Check the arity
          @mutex.synchronize {
            result = _execute(WakameOS::Utility::Job::RubyProc.new({
                                                                     :code => WakameOS::Utility::ProcSerializer.dump({}, &block),
                                                                     :argv => argv,
                                                                   }))
          }
          return Ping.new(result)
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
          amqp = WakameOS::Client::Environment.create_amqp_client
          amqp.start

          gc_targets = []
          logger.debug "Making a code queue."
          response_queue_name = nil
          gc_targets << request_queue_name  = "wakame.remote.request-#{WakameOS::Utility::UniqueKey.new}"
          gc_targets << response_queue_name = "wakame.remote.response-#{WakameOS::Utility::UniqueKey.new}" if need_response
          WakameOS::Client::SystemCall.instance.add_gc_target_queues(gc_targets)
          request_queue  = amqp.queue(request_queue_name,  :auto_delete => true)
          response_queue = amqp.queue(response_queue_name, :auto_delete => true) if need_response

          request_queue.publish(::Marshal.dump(job))
          logger.debug "Insert a job request into the queue from #{@credential[:instance_name]}."
          response = @agent.process_jobs(@credential,
                                         [{:request => request_queue_name, :response => response_queue_name}],
                                         @spec_name)
          logger.debug "Response: " + response.inspect

          result = response[:waiting_jobs][0] # ever one item.
          queue_count = response[:queue_count] || 0
          if response[:waiting_agents].size < queue_count
            logger.debug "New instance is required with #{@credential.inspect}."
            @instance.create_instances(@credential, @spec_name)
          end
          logger.debug "done the request."
          
          if need_response
            item = nil
            need_loop = true
            begin 
              item = response_queue.pop
              logger.debug "RESPONSE (MARSHAL): " + item.inspect
              if need_loop = (item[:payload]==:queue_empty)
                sleep 0.5 # TODO: lazy wait
              end
            end while need_loop
            result = ::Marshal.load(item[:payload])
            logger.debug "RESPONSE #{response_queue_name} (OBJECT): " + result.inspect
            response_queue.delete
          end

          WakameOS::Client::SystemCall.instance.remove_gc_target_queues(gc_targets)
          amqp.stop
          result
        end
        protected :_execute

        class Ping
          attr_reader :job_id

          def initialize(job_id)
            @job_id       = job_id.dup
            @update_on    = DateTime.now
            @cache_result = nil
          end

          def job_status
            now = DateTime.now
            if ((now - @update_on)*24*60*60*10).to_i > 5 || !@cache_result
              @update_on = now
              rpc = WakameOS::Client::SyncRpc.new('agent')
              begin
                result = nil
                timeout(5) {
                  result = rpc.job_status(@job_id).dup
                }
                @cache_result = result if result
                logger.debug "cached result: #{@cache_result.inspect}"
              rescue =>e
                # nothing to do
              end
            end
            return @cache_result
          end

          def available?
            return job_status[:available]
          end

          def processing?
            return job_status[:processing]
          end

          def agent_id
            return job_status[:agent_id]
          end

        end # Ping

      end # Remote

    end # Process

  end
end
