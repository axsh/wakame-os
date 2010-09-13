# -*- coding: undecided -*-
#
require 'clios'
require 'cloud'
require 'wakame'

require 'thread'
require 'monitor'

#
module WakameOS
  class Agent

    include Logger

    #####################################################################
    # Member
    attr_reader :client
    attr_reader :boot_token, :agent_id, :alive
    attr_reader :instance_name, :queue_name
    
    #####################################################################
    # Entry the Service as an Agent
    include WakameOS::Service::Kernel
    def initialize(boot_token)

      @boot_token           = boot_token
      @agent_id             = nil
      # @credential           = nil
      @spec_name            = nil

      @alive                = true
      @working              = false
      @assigned             = false

      @heart_beat_interval  = 10
      @job_picking_interval = 5
      @client_mutex         = Monitor.new
      @queue_name           = ''

      credential = {:boot_token => boot_token}

      # Negotiation
      @client = WakameOS::Client::SyncRpc.new('agent')
      results = @client.entry_agents([credential])
      results.each do |result|
        @agent_id      = result[:agent_id  ]
        # @credential    = result[:credential]
        @instance_name = result[:instance_name]
        @spec_name     = result[:spec_name ]
        @queue_name    = result[:queue_name]
      end
      logger.info "Entry: #{results.inspect}"
      
      # Finalization
      [:EXIT, :TERM].each do |sig|
        Signal.trap(sig){
          logger.info "Shutting down..."
          self.destroy
          exit(0)
        }
      end

      # Heart beat
      @heart_beat = Thread.new {
        loop_flag = true
        begin
          sleep(@heart_beat_interval.to_f+::Kernel.rand)
          touch(@working)
        end while loop_flag
      }
      
      # Job Picker
      @job_picker = Thread.new {
        queue = nil

        logger.info "Job picker setup."
        amqp = WakameOS::Client::Environment.create_amqp_client
        amqp.start
        queue = amqp.queue(@queue_name, :auto_delete => true, :exclusive => false)
        thread_queue = Queue.new

        loop_flag = true
        request_count = 0
        begin
          request_count += 1
          logger.info "Waiting a job..."
          data = queue.pop
          logger.info "Agent ID: #{@agent_id} picked a job up from #{@queue_name} ... #{data.inspect}"
          unless data[:payload]==:queue_empty
            # WE GOT A JOB REQUEST
            touch

            job = ::Marshal.load(data[:payload])
            logger.info "** A job will come from #{job.inspect}"

            @client_mutex.synchronize {
              @assigned = true if @client.assign_job(_credential, job.name)
            }

            # job.credential
            # job.spec_name
            direct_queue = amqp.queue(job.job[:request], :auto_delete => true)
            counter = 10
            begin
              logger.info "Waiting a receiving code..."
              direct_data = direct_queue.pop
              unless direct_data[:payload]==:queue_empty
                # WE FIND A JOB!
                @working = true
                program = ::Marshal.load(direct_data[:payload])
                direct_queue.delete
                code = ''
                argv = nil
                result = nil
                must_call_function = false

                case program.class.name
                when 'WakameOS::Utility::Job::RubyProc'
                  code = program.body[:code]
                  argv = program.body[:argv]
                  must_call_function = true
                when 'WakameOS::Utility::Job::RubyPlainCode'
                  code = program.body[:code]
                else
                  result = UnknownProtocol.new("#{program.class.name} is not allow to execute.")
                end

                logger.info "** Job arrival: #{code}"
                thread = Thread.new {

                  Wakame::Environment.os_instance_name = @instance_name
                  c = Class.new
                  c.instance_eval(code)

                  # TODO: Check the arity
                  if must_call_function
                    begin
                      if argv
                        logger.info "*** with argv: #{argv.inspect}"
                        result = c.remote_task(*argv) 
                      else
                        result = c.remote_task
                      end
                    rescue => e
                      logger.info "Remote method raise an exception: #{e.inspect}"
                      result = e
                    end
                  end

                  if job.job[:response]
                    response_queue = amqp.queue(job.job[:response], :auto_delete => true)
                    response_queue.publish(::Marshal.dump(result))
                  end
                }
                thread.join
                request_count = 0
                break
              else
                sleep(@job_picking_interval)
                counter -= 1
                logger.info "No any job. Retry counter is #{counter}."
              end
            end while counter>0

            @client_mutex.synchronize {
              @assigned = false if @client.finish_job(_credential, job.name)
            }
            logger.info "Exit, try to find a next job."
          end
          @working = false

          # Calibration of waiting...
          if request_count > 10 # TODO: Lazy magic number
            sleep(@job_picking_interval)
          else
            sleep 0.1 # TODO: Lazy magic number
          end
        end while loop_flag
      }

    end

    def touch(working=true)
      @client_mutex.synchronize {
        @client.touch_agents([_credential]) if working
      }
    end

    def destroy
      @client_mutex.synchronize {
        @client.leave_agents([_credential]) if @alive
      }
      Thread.kill(@heart_beat)
      @alive = false
    end

    def _credential
      {
        :boot_token => @boot_token,
        :agent_id   => @agent_id,
      }
    end
    protected :_credential

    class UnknownProtocol < Exception; end

  end
end
