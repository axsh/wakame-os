# -*- coding: undecided -*-
#
require 'clios'
require 'cloud'

require 'thread'
require 'monitor'

require 'rubygems'
require 'bunny'

#
module WakameOS
  class Agent

    class AgentBehavior
    end

    #####################################################################
    # Member
    attr_reader :client
    attr_reader :boot_token, :agent_id, :alive
    attr_reader :queue_name
    
    #####################################################################
    # Entry the Service as an Agent
    include WakameOS::Service::Kernel
    def initialize(boot_token)

      @boot_token           = boot_token
      @agent_id             = nil
      @credential           = nil
      @spec_name            = nil

      @alive                = true
      @working              = false
      @assigned             = false

      @heart_beat_interval  = 10
      @job_picking_interval = 1
      @client_mutex         = Monitor.new
      @queue_name           = ''

      agent_behavior = AgentBehavior.new
      
      # Entry Service
      rpc "agent_behavior.#{boot_token}", agent_behavior
      credential = {:boot_token => boot_token}

      # Negotiation
      @client = WakameOS::Client::SyncRpc.new('agent')
      results = @client.entry_agents([credential])
      results.each do |result|
        @agent_id   = result[:agent_id  ]
        @credential = result[:credential]
        @spec_name  = result[:spec_name ]
        @queue_name = result[:queue_name]
      end
      print "Entry: #{results.inspect}\n"
      
      # Finalization
      [:EXIT, :TERM, :HUP].each do |sig|
        Signal.trap(sig){
          self.destroy
          exit(0)
        }
      end

      # Heart beat
      @heart_beat = Thread.new {
        loop_flag = true
        begin
          sleep(@heart_beat_interval+(::Kernel.rand(10)/10.0))
          touch(@working)
        end while loop_flag
      }
      
      # Job Picker
      @job_picker = Thread.new {
        queue = nil

        print "Job picker setup.\n"
        bunny = Bunny.new(:spec => '08') # configure from command line option
        bunny.start
        queue = bunny.queue(@queue_name, :auto_delete => true, :exclusive => false)
        thread_queue = Queue.new

        loop_flag = true
        begin
          print "Waiting a job...\n"
          data = queue.pop
          print "Agent ID: #{@agent_id} picked a job up from #{@queue_name} ... #{data.inspect}\n"
          unless data[:payload]==:queue_empty
            # WE GOT A JOB REQUEST
            touch

            job = ::Marshal.load(data[:payload])
            print "** A job will come from #{job.inspect}\n"

            @client_mutex.synchronize {
              @assigned = true if @client.assign_job(_credential, job.job_id)
            }

            # job.credential
            # job.spec_name
            direct_queue = bunny.queue(job.job_id, :auto_delete => true)
            counter = 10
            begin
              print "Waiting a receiving code...\n"
              direct_data = direct_queue.pop
              unless direct_data[:payload]==:queue_empty
                # WE FIND A JOB!
                @working = true
                hash = ::Marshal.load(direct_data[:payload])
                direct_queue.delete
                
                code = hash[:code]
                argv = hash[:argv]
                result = nil

                print "** Job arrival: #{code}\n"
                thread = Thread.new {
                  eval(code)

                  # TODO: Check the arity
                  begin
                    if argv
                      print "*** with argv: #{argv.inspect}\n"
                      result = remote_task(*argv) 
                    else
                      result = remote_task
                    end
                  rescue => e
                    print "Remote method raise an exception: #{e.inspect}\n"
                    result = e
                  end

                  # TODO: send response

                  @client_mutex.synchronize {
                    @assigned = false if @client.finish_job(_credential, job.job_id)
                  }
                  
                }
                thread.join

                break
              else
                sleep(@job_picking_interval)
                counter -= 1
                print "No any job. Retry counter is #{counter}.\n"
              end
            end while counter>0
            print "Exit, try to find a next job.\n"
          end
          @working = false
          sleep(@job_picking_interval)
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

  end
end
