require 'thread'
require 'monitor'

module WakameOS
  module Cloud
    class PermanentHost < Base

      @@instances = {}
      @@instances_mutex = Monitor.new

      @@agents = {}
      @@agent_mutex = Monitor.new

      def initialize(config)
      end

      def list_instances
        _purge
        ret = []
        @@instances_mutex.synchronize {
          ret = @@instances.values.dup
        }
        ret
      end

      def reboot_instances(global_name_array)
        _purge
        true
      end

      def create_instances(option_hash_array)
        _purge
        ret = []
        option_hash_array.each do |option_hash|
          i = Instance.new(self)
          i.provider = 'permanent_host'
          i.global_name = 'PH:'+Digest::MD5.hexdigest(i.object_id.to_s)[0..10]
          i.local_name = i.global_name
          i.state = Instance::Status::RUNNING
          i.public_ips = []
          i.private_ips = [] # what is best?
          i.extra_information = {}
          ret << i
          @@instances_mutex.synchronize {
            @@instances[i.global_name] = i
          }

          parent_global_name = option_hash[:wakame_parent_instance_name]
          _start_agent(i.global_name, parent_global_name)
        end
        ret
      end

      def destroy_instances(global_name_array)
        _purge
        ret = []
        @@instances_mutex.synchronize {
          global_name_array.each do |global_name|
            instance = @@instances[global_name]
            if instance
              _stop_agent(instance.global_name)
              instance.touch
              instance.state = Instance::Status::TERMINATED
              ret << global_name
            end
          end
        }
        ret
      end

      def list_images
        # TODO: list_images
        raise NotImplemented.new
      end

      def list_specifications
        # TODO: list_specifications
        raise NotImplemented.new
      end

      def list_locations
        # TODO: list_locations
        raise NotImplemented.new
      end

      def _purge
        now = DateTime.now
        @@instances_mutex.synchronize {
          mark_to_delete = []
          @@instances.values.each do |instance|
            mark_to_delete << instance.global_name if
              ((now-instance.update_on)*24*60*60).to_i>=60 &&
              instance.state==Instance::Status::TERMINATED
          end
          mark_to_delete.each do |global_name|
            @@instances.delete(global_name)
          end
        }
      end
      protected :_purge

      def _start_agent(global_name, parent_global_name=nil)
        pid = nil
        @@agent_mutex.synchronize {
          pid = @@agents[global_name]
          @@agents[global_name] = 0 # any object
        }
        return if pid!=nil
        if !(pid = Process.fork)
          argv  = ['./bin/agent', '--token', global_name.to_s]
          argv += ['--parent', parent_global_name] if parent_global_name
          exec *argv
          exit
        end
        @@agent_mutex.synchronize {
          @@agents[global_name] = pid
        }
      end
      protected :_start_agent

      def _stop_agent(global_name)
        @@agent_mutex.synchronize {
          pid = @@agents.delete(global_name)
          if pid && pid>0
            begin
              Process.kill(:HUP, pid)
            rescue => e
              # process is already killed?
            end
            begin
              timeout(0.1) {
                loop do
                  Process.wait # just to be safe...
                end
              }
            rescue Timeout::Error => e
              # child is already gone.
            end
          end
        }
      end
      protected :_stop_agent

    end
  end
end
