module WakameOS
  module Cloud
    class Base

      def initalize(config)
      end

      def list_instances
        raise NotImplemented.new
      end

      def reboot_instances(global_name_array)
        raise NotImplemented.new
      end

      def create_instances(option_hash_array)
        raise NotImplemented.new
      end

      def destroy_instances(global_name_array)
        raise NotImplemented.new
      end

      def list_images
        raise NotImplemented.new
      end

      def list_specifications
        raise NotImplemented.new
      end

      def list_locations
        raise NotImplemented.new
      end

      class NotImplemented < Exception; end

    end
  end
end
