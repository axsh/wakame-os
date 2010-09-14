require 'rubygems'
require 'wakame'
require 'rational'

credential = Wakame::Environment.os_user_credential

process = Wakame::Process.setup( :credential => credential,
                                 :spec_name  => 'unknown'
                                 )

queue   = Wakame::Queue.setup

# How many compute?
dist = 30
challange = 1000000

dist.times { |no|
  process.fork(no, challange, queue) { |no, challange, queue|
    hit  = 0
    
    challange.times { 
      x = rand
      y = rand
      hit += 1 if x*x+y*y<1.0
    }
    queue.push [no, Rational(hit, challange)]

  }
}

print "Process were distributed. Waiting results...\n"

rat = 0
dist.times { |i|
  data = queue.pop
  print "Arrival result #{i+1}/#{dist} from node number. #{data[0]} -> #{data[1]}\n"
  rat += data[1]
}
print "Final result. PI = #{(rat * Rational(4, dist)).to_f}\n"

