# -*- coding: utf-8 -*-

require 'log4r'

module WakameOS
  # Injects +logger+ method to the included class.
  # The output message from the logger methods starts the module name trailing message body.
  module Logger

    # Isono top level logger
    rootlog = Log4r::Logger.new('WakameOS')
    formatter = Log4r::PatternFormatter.new(:depth => 9999, # stack trace depth
                                            :pattern => "%d %c [%l]: %M",
                                            :date_format => "%Y/%m/%d %H:%M:%S"
                                            )
    rootlog.add(Log4r::StdoutOutputter.new('stdout', :formatter => formatter))
    
    
    def self.included(klass)
      klass.class_eval {

        @class_logger = Log4r::Logger.new(klass.to_s)

        def self.logger
          @class_logger
        end

        def logger
          @instance_logger || self.class.logger
        end
        
        def self.logger_name
          @class_logger.path
        end

        #def self.logger_name=(name)
        #  @logger_name = name
        #end

        def set_instance_logger(suffix=nil)
          suffix ||= self.__id__.abs.to_s(16)
          @instance_logger = Log4r::Logger.new("#{self.class} for #{suffix}")
        end
      }
    end

  end
end
