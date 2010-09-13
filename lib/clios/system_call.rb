# -*- coding: undecided -*-
#
require 'clios'
require 'cloud'
require 'util'

require 'md5'
require 'date'
require 'thread'
require 'monitor'

#
module WakameOS
  class SystemCall

    #####################################################################
    module Privilege
      attr_accessor :credential
      def allow?(my_credential)
        return false unless @credential
        @credential[:user] == my_credential[:user]
      end
    end

    #####################################################################
    # Instance
    class InstanceController
      include Logger

      class HybridInstance
        include Privilege

        @@sequencial_number_mutex = Monitor.new
        @@sequencial_number = ::Kernel.rand(999_999_999_999)

        def self.create(credential, driver_name, spec_name, instance)
          self.new(credential, driver_name, spec_name, instance)
        end

        attr_reader   :boot_token
        attr_reader   :credential
        attr_accessor :driver_name, :spec_name

        attr_accessor :instance_name, :parent_instance_name, :child_instance_names
        attr_accessor :life_time
        attr_accessor :state, :create_on, :update_on, :alive
        
        # TODO: Monitoring
        # attr_accessor :cpu_usage, :memory_usage

        def add_child_name(name)
          (@child_instance_names << name).uniq!
        end

        def remove_child_name(name)
          @child_instance_names -= [name]
        end

        def touch
          @update_on = DateTime.now
        end
        
        def destroy
          @alive = false
        end

        def to_hash
          {
            :boot_token => @boot_token,
            :user => @credential[:user],
            :driver => @driver_name,
            :specification => @spec_name,
            :instance_name => @instance_name,
            :parent_instance_name => @parent_instance_name,
            :child_instance_names => @child_instance_names,
            :state => @state,
            :alive => @alive,
            :life_time => @life_time,
            :create_on => @create_on.to_s,
            :update_on => @update_on.to_s,
          }
        end

        private
        def initialize(credential, driver_name, spec_name, spec, instance, parent_instance_name=nil)

          @@sequencial_number_mutex.synchronize {
            @boot_token = Digest::MD5.hexdigest(`/sbin/ip route get 8.8.8.8`+Time.now.to_i.to_s+@@sequencial_number.to_s)
            @@sequencial_number += 1
          }

          @credential = credential
          @driver_name = driver_name
          @spec_name = spec_name || 'default'
          @instance_name = instance.global_name
          @parent_instance_name = parent_instance_name
          @child_instance_names = []
          @state = instance.state.to_s
          @alive = true
          life_time = spec.life_time
          @life_time = { # in sec
            :pending       => life_time.pending       ||  55*60,
            :running       => life_time.running       ||  55*60,
            :rebooting     => life_time.rebootine     ||  55*60,
            :shutting_down => life_time.shutting_down ||  55*60,
            :terminated    => life_time.terminated    ||   1*60,
            :accidental    => life_time.accidental    ||   1*60,
          }

          @create_on = DateTime.now
          @update_on = DateTime.now
        end
      end
      #####################################################################

      # Member
      attr_accessor :catalog
      attr_reader :instances
      attr_accessor :patrol_interval_sec
      
      # Initialize
      def initialize
        @instances = {}
        @instances_by_boot_token = {}
        @instance_list_mutex = Monitor.new

        @patrol_credentials = {}
        @patrol_interval_sec = 5

        @catalog = WakameOS::Configuration.cloud_catalog.dup
      end

      # Instance Methods / Operation Layer
      def list_instances(credential=nil)
        ret = []
        @instance_list_mutex.synchronize {
          @instances.values.each do |instance|
            ret.push(instance.to_hash) if !credential || instance.allow?(credential)
          end
        }
        ret
      end

      def search_instance(boot_token_or_instance_name)
        ret = nil
        @instance_list_mutex.synchronize {
          boot_token    = boot_token_or_instance_name
          instance_name = boot_token_or_instance_name
          ret = @instances_by_boot_token[boot_token]
          ret = @instances[instance_name] unless ret
        }
        raise InstanceNotFound.new("Search keyword \"#{boot_token_or_instance_name}\" does not found in list.") unless ret
        ret
      end

      def create_instances(credential, spec_name='default')
        return [] if !@catalog
        ret = []
        spec = @catalog.spec(spec_name)
        if spec
          driver = _get_driver(spec)
          instances = driver.create_instances([_uncapsuled(spec.requirement).to_hash_from_table])
          instances.each do |instance|
            parent_instance_name = credential.delete(:instance_name)
            wakame_instance = HybridInstance.new(credential, spec.driver, spec_name, spec, instance, parent_instance_name)
            @instance_list_mutex.synchronize {
              @instances_by_boot_token[wakame_instance.boot_token] = wakame_instance
              @instances[wakame_instance.instance_name] = wakame_instance
              ret << wakame_instance.instance_name.dup
              @instances[parent_instance_name].add_child_name(wakame_instance.instance_name) if parent_instance_name
            }
          end
        else
          raise SpecificationNotFound.new('Specification "'+spec_name.to_s+'" not found.')
        end
        ret
      end
      
      def destroy_instances(credential, name_array)
        return [] unless name_array.is_a?(Array) && name_array.size>0

        ret = []
        @instance_list_mutex.synchronize {
          target_array = []
          name_array.each do |name|
            target_array += _destroy_instances_recursive(name)
          end
          logger.info "destroy target (include children): "+ target_array.inspect
          
          target_array.uniq.each do |name|
            instance = @instances[name]
            if instance
              spec = @catalog.spec(instance.spec_name)
              driver = _get_driver(spec)
              if driver.destroy_instances([instance.instance_name])
                ret << instance.instance_name
                @instances[instance.parent_instance_name].remove_child_name(instance.instance_name) if instance.parent_instance_name
              end
            end
          end
        }
        ret
      end
      def _destroy_instances_recursive(instance_name)
        ret = [instance_name]
        @instances[instance_name].child_instance_names.each do |child_instance_name|
          ret += _destroy_instances_recursive(child_instance_name)
        end
        ret
      end
      protected :_destroy_instances_recursive
      
      def reboot_instances(credential, name_array)
        return false unless name_array.is_a?(Array) && name_array.size>0
        # TODO: need imprementation
        # @cloud_controller.reboot_instances(name_array)
        true
      end
      
      # Protected methods
      def _uncapsuled(ostruct)
        unless ostruct.respond_to? :to_hash_from_table
          def ostruct.to_hash_from_table
            table
          end
        end
        ostruct
      end
      protected :_uncapsuled
      
      def _get_driver(spec)
        driver_name = spec.driver
        credential = _uncapsuled(@catalog.credential(spec.credential)).to_hash_from_table
        driver = WakameOS::Cloud::Driver.create(driver_name, credential)
        _entry(driver, driver_name, credential)
        driver
      end
      protected :_get_driver
      
      def _entry(driver, driver_name, credential={})
        value = {
          :driver_name => driver_name,
          :user => credential[:user],
        }
        unless @patrol_credentials.key? value.hash
          @patrol_credentials[value.hash] = value
          Thread.new do 
            loop_flag = true
            chance_to_retry = 5
            mark_to_destroy = []
            begin
              sleep(@patrol_interval_sec || 5)

              logger.info "Instance stats checking..."
              online_instances = []
              onmemory_instances = []
              iaas_has_any_trouble = false
              @instance_list_mutex.synchronize {
                begin
                  is = driver.list_instances
                  is.each do |instance|
                    online_instances << instance.global_name.dup
                    wakame_instance = @instances[instance.global_name]
                    if wakame_instance && wakame_instance.state!=instance.state.to_s
                      wakame_instance.touch
                      wakame_instance.state = instance.state.to_s
                    end
                  end
                rescue => e
                  # TODO: identify the exception
                  logger.warn "Does IaaS have any trouble? Instance list not found via driver \"#{driver_name}.\""
                  iaas_has_any_trouble = true
                end

                logger.info "running gabage collector..."
                now = DateTime.now
                mark_to_delete = []
                @instances.each do |key, instance|
                  if instance.driver_name==driver_name
                    onmemory_instances << key.dup
                    duration_sec = ((now-instance.update_on)*24*60*60).to_i
                    if duration_sec >= (instance.life_time[instance.state.to_sym] || 1*60)
                      case instance.state.to_s
                      when 'terminated'
                        logger.info "#{instance.instance_name} will be delete from memory."
                        mark_to_delete << key.dup
                      else
                        logger.info "#{instance.instance_name} will be shutted down."
                        mark_to_destroy << [instance.credential.dup, instance.instance_name.dup] 
                      end
                    end
                  end
                end

                logger.info "deletion target: "+ mark_to_delete.inspect
                logger.info "destroy target: "+ mark_to_destroy.inspect

                unless iaas_has_any_trouble
                  logger.info "checking invisible instance with unpredictable reason..."
                  # p onmemory_instances.inspect
                  # p online_instances.inspect
                  (onmemory_instances - online_instances).each do |global_name|
                    logger.warn "Gone Instance? > #{global_name}"
                    @instances[global_name].state = "accidental"
                  end
                end

                logger.info "delete from memory..."
                mark_to_delete.each do |key|
                  instance = @instances.delete(key)
                  @instances_by_boot_token.delete(instance.boot_token)
                  instance.destroy if instance
                end

                logger.info "destroy from server farm..."
                carry_forward = []
                mark_to_destroy.each do |credential, instance_name|
                  begin
                    destroy_instances(credential, [instance_name])
                  rescue => e
                    # TODO: identify the exception
                    logger.warn "Failure to destroy? #{instance_name} Exception: #{e.inspect}"
                    carry_forward << [credential, instance_name]
                  end
                end
                mark_to_destroy = carry_forward

                # Finished? I warry about all patrol threads are gone by timing.
                loop_flag = true
                if iaas_has_any_trouble==false &&
                    (online_instances.size<=0 && onmemory_instances.size<=0)
                  if (chance_to_retry-=1)<=0
                    @patrol_credentials.delete(value.hash)
                    loop_flag = false
                  end
                else
                  chance_to_retry = 5
                end
              }
              logger.info "Instance stats updated."
            end while loop_flag
            logger.info "Patrol thread is finished working."
          end
        end
      end
      protected :_entry
      
      class InstanceNotFound < Exception; end
      class SpecificationNotFound < Exception; end
    end
    
    #####################################################################
    # Agent
    class AgentController
      include Logger
      class Agent
        include Privilege

        attr_reader :agent_id, :instance, :spec_name
        attr_reader :job_id

        def initialize(instance)
          @instance = instance
          @credential = instance.credential
          @spec_name = instance.spec_name.dup
          @agent_id = instance.instance_name
          @alive = true
          @job_id = nil
          @create_on = DateTime.now
          @update_on = DateTime.now
          @woke_on = DateTime.now
          @work_time = 0.0
        end
        
        def touch
          @update_on = DateTime.now
          @instance.touch if @instance && @instance.alive
        end
        
        def alive
          @alive = false
          @alive = @instance.alive if @instance
          return @alive
        end

        def destroy
          @alive = false
          @instance = nil
          true
        end

        def work_time
          now = DateTime.now
          if @job_id
            @work_time += now - @work_on
            @work_on = now
          end
          return (@work_time / (now - @create_on)).to_f
        end

        def assign_job(job_id)
          finish_job
          @work_on = DateTime.now
          @job_id = job_id
        end
        
        def finish_job
          return unless @job_id
          now = DateTime.now
          @job_id = nil
          @work_time += now - @work_on
        end

        def to_hash
          {
            :agent_id  => @agent_id,
            :alive     => @alive,
            :job_id    => @job_id,
            :work      => self.work_time,
            :instance  => (@instance || {}).to_hash,
            :create_on => @create_on.to_s,
            :update_on => @update_on.to_s,
          }
        end
      end
      
      class Job
        attr_reader :job, :credential, :spec_name
        def initialize(job, credential,  spec_name)
          @job        = job
          @credential = credential
          @spec_name  = spec_name
          @job_id     = WakameOS::Utility::UniqueKey.new
        end
        def to_hash
          {
            :job_id => @job_id,
            :job => @job,
          }
        end
        def name
          "#{@job_id}"
        end
      end
      
      ##################################################################
      
      @@amqp_mutex = Monitor.new
      
      attr_reader :instance_controller
      attr_reader :agents, :agent_list_mutex, :agents_index
      attr_reader :patrol_credentials, :patrol_interval_sec
      
      def initialize(instance_controller)
        @instance_controller = instance_controller
        
        @queue_name_prefix = 'wakame.job.spec.'
        @agents = {}
        @agent_list_mutex = {}
        @agents_index = {}
        @agents_index_mutex = Monitor.new
        @job_assign = {}
        @job_assign_mutex = Monitor.new

        @patrol_interval_sec = 5
        @patrol_credentials = {}
      end

      ##################################
      # Instance method / Operaion layer

      def list_jobs(user_credential=nil)
        list_agents(user_credential, true)
      end

      def list_agents(user_credential=nil, has_job=false)
        ret = []
        if user_credential
          hash = _user_credential_hash(user_credential)
          _agent_list_mutex(hash).synchronize {
            _agents(hash).values.each do |agent|
              ret.push(agent.to_hash) if 
                agent.allow?(user_credential) && 
                ((has_job && agent.job_id) || !has_job)
            end
          }
        else
          @agents_index_mutex.synchronize {
            @agents_index.values.each do |agent|
              ret.push(agent.to_hash) if
                (has_job && agent.job_id) || !has_job
            end
          }
        end
        ret
      end

      # Agent (Waiting worker) Registration
      # Notes: this credential is for to identify the agent, not user!
      def entry_agents(credential_array)
        return [] unless credential_array.is_a? Array
        ret = []
        credential_array.each do |credential|
          if (boot_token = credential[:boot_token])
            instance = nil
            begin
              instance = @instance_controller.search_instance(boot_token)
              agent = Agent.new(instance)
              agent_id = agent.agent_id
              hash = _user_credential_hash(instance.credential)
              _agent_list_mutex(hash).synchronize {
                _agents(hash, agent_id, agent) # update
                @agents_index_mutex.synchronize {
                  @agents_index[agent_id] = agent
                }
                _entry(instance.credential)
              }
              ret << {
                :agent_id      => agent_id,
                #:credential    => agent.instance.credential,
                :instance_name => agent.instance.instance_name,
                :spec_name     => agent.spec_name,
                :queue_name    => queue_name(agent.instance.credential, agent.spec_name),
              }
            rescue InstanceController::InstanceNotFound => e
              ret = e
            end
          end
        end
        ret
      end
      
      # Assign a job (agent's credential)
      def assign_job(credential, job_id)
        ret = false
        if (agent_id = credential[:agent_id])
          @job_assign_mutex.synchronize {
            @agents_index_mutex.synchronize {
              agent = @agents_index[agent_id]
              unless agent.job_id
                @job_assign[agent_id] = agent
                agent.assign_job(job_id)
                ret = true
              end
            }
          }
        end
        ret
      end
      
      # Keep alive
      def touch_agents(credential_array)
        ret = []
        credential_array.each do |credential|
          if (agent_id = credential[:agent_id])
            agent = nil
            @agents_index_mutex.synchronize {
              agent = @agents_index[agent_id]
            }
            _agent_list_mutex(_user_credential_hash(agent.instance.credential)).synchronize {
              agent.touch if agent
            }
          end
       end if credential_array.is_a? Array
        ret
      end
      
      # Finished the job
      def finish_job(credential, job_id)
        ret = false
        if (agent_id = credential[:agent_id])
          @job_assign_mutex.synchronize {
            @agents_index_mutex.synchronize {
              agent = @job_assign.delete(agent_id)
              if agent && agent.job_id
                agent.finish_job
                ret = true
              end
            }
          }
        end
        ret
      end

      # Good-bye.
      def leave_agents(credential_array)
        ret = []
        credential_array.each do |credential|
          if (agent_id = credential[:agent_id])
            @agents_index_mutex.synchronize {
              agent = @agents_index[agent_id]
              hash = _user_credential_hash(agent.instance.credential)
              _agent_list_mutex(hash).synchronize {
                agent = _agents(hash).delete(agent_id)
                agent.destroy if agent
                @agents_index.delete(agent_id)
              }
            }
          end
        end if credential_array.is_a? Array
        ret
      end
      
      # Job Registration (use a user credential)
      def queue_name(credential, spec_name='default')
        parent_instance_name = credential[:instance_name] || ''
        @queue_name_prefix + parent_instance_name + '.' + spec_name + '.' + Digest::MD5.hexdigest(credential[:user] || '')
      end
      
      def process_jobs(credential, job_array, spec_name='default')
        return false unless job_array.is_a?(Array) && job_array.size>0
        
        # entry the jobs
        waiting_jobs = []
        waiting_agents = []
        queue_count = nil

        queue = nil
        name = queue_name(credential, spec_name)
        @@amqp_mutex.synchronize {
          amqp = WakameOS::Client::Environment.create_amqp_client
          amqp.start

          queue = amqp.queue(name,
                             :auto_delete => true,
                             :exclusive => false) unless queue

          job_array.each do |job|
            job_package = Job.new(job, credential, spec_name)
            queue.publish(::Marshal.dump(job_package))
            waiting_jobs << job_package.name
          end
          queue_count = queue.message_count

          hash = _user_credential_hash(credential)
          _agent_list_mutex(hash).synchronize {
            agents = _agents(hash)
            (agents.keys - @job_assign.keys).each do |agent_id|
              waiting_agents << {:agent_id => agent_id, :work => agents[agent_id].work_time}
            end
          }
          amqp.stop
        }

        {:waiting_jobs => waiting_jobs, :waiting_agents => waiting_agents, :queue_count => queue_count || waiting_agents.size}
      end
      
      # Pop a job (use a user credential)
      def pop_job(credential, spec_name='default')
        ret = :queue_empty
        @@amqp_mutex.synchronize {
          amqp = WakameOS::Client::Environment.create_amqp_client
          amqp.start
          ret = queue.pop.dup
          amqp.stop
        }
        ret = ::Marshal.load(ret) if ret && (ret = ret[:payload])!=:queue_empty
        ret
      end
      
      # protected methods
      def _agents(hash, agent_id=nil, agent=nil)
        unless agent_id
          agents = @agents[hash]
          agents = @agents[hash] = {} unless agents
          return agents
        end
        agents = _agents(hash)
        already_agent = agents[agent_id]
        agents[agent_id] = agent if agent # update
        return already_agent
      end
      protected :_agents

      def _user_credential_hash(user_credential)
        {
          :user => user_credential[:user],
        }.hash
      end
      protected :_user_credential_hash

      def _agent_list_mutex(user_credential_hash)
        mutex = @agent_list_mutex[user_credential_hash]
        mutex = @agent_list_mutex[user_credential_hash] = Monitor.new unless mutex
        return mutex        
      end
      protected :_agent_list_mutex

      def _entry(user_credential)
        # We do not need credential of accessing to clouds
        hash = _user_credential_hash(user_credential)
        unless @patrol_credentials.key? hash
          @patrol_credentials[hash] = user_credential
          Thread.new {
            loop_flag = true
            begin
              sleep(@patrol_interval_sec || 10)
              logger.info "Checking agents..."
              mark_to_delete = []
              _agent_list_mutex(hash).synchronize {
                _agents(hash).each do |agent_id, agent|
                  mark_to_delete << agent_id.dup unless agent.instance && agent.instance.alive
                end
                mark_to_delete.each do |agent_id|
                  agent = _agents(hash).delete(agent_id)
                  logger.info "Agent ID: #{agent_id} is gone."
                  agent.destroy
                  @agents_index_mutex.synchronize {
                    @agents_index.delete(agent_id)
                  }
                end
              }
            end while loop_flag
          }
        end
      end
      protected :_entry
      
    end
    
    #####################################################################
    # Entry the Service as System-call
    
    include WakameOS::Service::Kernel
    def initialize  
      instance_controller = InstanceController.new
      agent_controller    = AgentController.new(instance_controller)
      
      # Entry
      rpc 'instance', instance_controller
      rpc 'agent',    agent_controller
      
    end
    
  end
end
