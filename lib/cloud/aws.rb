#
require 'rubygems'
require 'right_aws' # TODO: replace the own handler to get low dependency and high performance

module WakameOS
  module Cloud
    class AWS < Base

      attr_reader :ec2

      def initialize(config)
        # :access_key, :secret_access_key
        @ec2   = RightAws::Ec2.new(config[:access_key],
                                   config[:secret_access_key])
      end

      def list_instances
        ret = []
        instances = @ec2.describe_instances
        instances.each do |instance|
          ret << _mapped_instance(instance)
        end if instances
        ret
      end

      def reboot_instances(global_name_array)
        target = []
        global_name_array = [global_name_array] unless global_name_array.is_a? Array
        global_name_array.uniq.each do |global_name|
          provider, local = global_name.split(':', 2)
          target << local
        end
        @ec2.reboot_instances(target) # true / false
      end

      def create_instances(option_hash_array)
        ret = []
        option_hash_array = [option_hash_array] unless option_hash_array.is_a? Array
        option_hash_array.each do |p|
          image_id = p[:image_id]
          min_count = p[:min_count] || 1
          max_count = p[:max_count] || 1
          security_group_ids = p[:group_ids] || ['default']
          key_pair_name = p[:key_name] || 'default'
          user_data = p[:user_data] || ''
          addressing_type = p[:addressing_type] || 'public'
          instance_type = p[:instance_type]
          kernel_id = p[:kernel_id]
          ramdisk_id = p[:ramdisk_id]
          availability_zone = p[:availability_zone]
          block_device_mappings = p[:block_device_mappings]

          instances = @ec2.run_instances(image_id, min_count, max_count, security_group_ids, key_pair_name, user_data, addressing_type,
                                         instance_type, kernel_id, ramdisk_id, availability_zone, block_device_mappings)
          instances.each do |instance|
            ret << _mapped_instance(instance)
          end
        end
        ret
      end

      def destroy_instances(global_name_array)
        target = []
        global_name_array = [global_name_array] unless global_name_array.is_a? Array
        global_name_array.uniq.each do |global_name|
          provider, local = global_name.split(':', 2)
          target << local
        end
        ret = []
        instances = @ec2.terminate_instances(target)
        instances.each do |instance|
          ret << _mapped_instance(instance)
        end
        ret # destroied instance list
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

      private
      def _mapped_instance(instance)
        i = Instance.new(self)
        i.provider = self.class.name.split('::').last
        i.global_name = i.provider + ':' + (instance[:aws_instance_id] || 'i-UNKNOWN')
        i.local_name = (instance[:aws_instance_id] || 'i-UNKNOWN')
        case instance[:aws_state]
        when 'pending'
          i.state = Instance::Status::PENDING
        when 'running'
          i.state = Instance::Status::RUNNING
        when 'shutting-down'
          i.state = Instance::Status::SHUTTING_DOWN
        when 'terminated'
          i.state = Instance::Status::TERMINATED
        when 'accidental'
          i.state = Instance::Status::ACCIDENTAL
        else
          i.state = Instance::Status::UNKNOWN
        end
        i.public_ips = [instance[:ip_address]]
        i.private_ips = [instance[:private_ip_address]]
        i.extra_information = instance.dup
        i
      end

    end
  end
end


