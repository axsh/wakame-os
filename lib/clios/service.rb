#
require 'clios'

require 'rubygems'
require 'mq'

#
module WakameOS
  module Service

    class Context
      attr_reader :rpc_procs, :rpc_classes
      def initialize
        @rpc_procs = []
        @rpc_classes = []
      end
      def add_rpc_proc(name, proc_object, &blk)
        @rpc_procs.push([name, proc_object, blk])
      end
      def add_rpc_class(name, klass, &blk)
        @rpc_classes.push([name, klass, blk])
      end
    end

    module Kernel

      def context
        $wakame_context ||= Context.new
      end
      
      def rpc(name, klass=nil, &blk)

        context.add_rpc_proc(name, blk) { |mq, name, blk|
          mq ||= MQ
          mq.queue(name, :auto_delete => true).subscribe(:ack=>true){ |info, request|
            info.ack
            EM.defer {
              method, *args = ::Marshal.load(request)
              # TODO: error check for arity
              ret = blk.call(method, *args)
              mq.queue(info.reply_to, :auto_delete => true).publish(::Marshal.dump(ret), :key => info.reply_to, :message_id => info.message_id) if info.reply_to
              mq.queues[info.reply_to] = nil
            }
          }
        } if block_given?

        context.add_rpc_class(name, klass) { |mq, name, klass|
          mq ||= MQ
          mq.queue(name, :auto_delete => true).subscribe(:ack=>true){ |info, request|
            info.ack
            EM.defer {
              method, *args = ::Marshal.load(request)
              begin
                # TODO: error check for arity
                ret = klass.send(method, *args)
              rescue => e
                # TODO: record to log
                ret = e
                p ret.inspect
              end
              mq.queue(info.reply_to, :auto_delete => true).publish(::Marshal.dump(ret), :key => info.reply_to, :message_id => info.message_id) if info.reply_to
              mq.queues[info.reply_to] = nil
            }
          }
        } if klass

      end

    end

  end
end

