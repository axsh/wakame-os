module WakameOS
  module Util

    module String
      # Copied from http://github.com/datamapper/extlib/blob/master/lib/extlib/string.rb#L35
      ##
      # Convert to snake case.
      #
      #   "FooBar".snake_case           #=> "foo_bar"
      #   "HeadlineCNNNews".snake_case  #=> "headline_cnn_news"
      #   "CNN".snake_case              #=> "cnn"
      #
      # @return [String] Receiver converted to snake case.
      #
      # @api public
      def snake_case
        return downcase if match(/\A[A-Z]+\z/)
        gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
          gsub(/([a-z])([A-Z])/, '\1_\2').
          downcase
      end
      
      # Copied from http://github.com/datamapper/extlib/blob/master/lib/extlib/string.rb#L53
      ##
      # Convert to camel case.
      #
      #   "foo_bar".camel_case          #=> "FooBar"
      #
      # @return [String] Receiver converted to camel case.
      #
      # @api public
      def camel_case
        return self if self !~ /_/ && self =~ /[A-Z]+.*/
        split('_').map{|e| e.capitalize}.join
      end

    end
  end
end

class String
  include WakameOS::Util::String
end
