module WakameOS
  module Utility

    module Job

      class Base
        attr_accessor :body
        def initialize(body=nil)
          @header = {}
          @body = body
        end
        def header=(hash)
          @header = hash
        end
        def header(key=nil)
          return @header unless key
          @header[key]
        end
      end

      class RubyProc      < Base; end
      class RubyFile      < Base; end
      class RubyPlainCode < Base; end

    end
  end
end
