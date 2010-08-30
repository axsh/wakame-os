# gem install ruby2ruby ParseTree
# ruby2ruby 1.2.4 is REQUIRED.

require 'rubygems'
require 'ruby2ruby'
require 'sexp_processor'
require 'unified_ruby'
require 'parse_tree'

module WakameOS
  module Utility
    class ProcSerializer
      # how to call:
      # (1) copy all local variables
      ## WakameOS::Utility::ProcSerializer.dump(local_variables.map{ |v| [v,eval(v)] }) {
      ##  # YOUR CODE
      ## }
      # (2) copy partial
      ## WakameOS::Utility::ProcSerializer.dump([["x", 1], ["y", 2]]) { |z|
      ##  # YOUR CODE
      ##  x + y + z
      ## }
      def self.dump(local_vars={}, &block)
        return '' unless block_given?
        c = Class.new
        c.class_eval do
          define_method :remote_task, &block
        end
        s = Ruby2Ruby.translate(c, :remote_task)
        excepts = s.split("\n")[0].gsub(/^def[^(]*\(([^)]*)\)/, '\1').split(',').map{ |x| x.strip }
        locals = local_vars.map { |var,val|
          unless excepts.include?(var)
            member = val.class.ancestors
            if member.include?(String) || member.include?(Numeric)
              "#{var} = #{val.inspect};\n"
            else
              marshal_instance(var, val)+"\n"
            end
          end
        }.join
        s.split("\n").insert(1, locals).join("\n")
      end
      
      def self.marshal_instance(variable_name, instance)
        "#{variable_name} = Marshal.load(#{Marshal.dump(instance).inspect});"
      end
      
    end
  end
end

# we got a monkey patch for r2r 1.2.4 from
# http://gist.github.com/321038
class Ruby2Ruby < SexpProcessor
  def self.translate(klass_or_str, method = nil)
    sexp = ParseTree.translate(klass_or_str, method)
    unifier = Unifier.new
    unifier.processors.each do |p|
      p.unsupported.delete :cfunc # HACK
    end
    sexp = unifier.process(sexp)
    self.new.process(sexp)
  end
end

class Module
  def to_ruby
    Ruby2Ruby.translate(self)
  end
end
