require 'rubygems'
require 'wakame'
require 'date'

credential = Wakame::Environment.os_user_credential

process = Wakame::Process.setup(:credential => credential,
                                :spec_name => 'unknown')

rutine = Proc.new { |t|
  print '-'*(16*t)+"\n"
  t.times do |i|
    print "Say Hello! #{i} / "
  end
  print "\n"
  print '-'*(16*t)+"\n"
}

threads = []
50.times { |i|
  threads << Thread.new {
    print "Thread #{i} setup.\n"
    process.fork(5+rand(10), &rutine) 
    print "done.\n"
  }
}

print "Waiting to join...\n"
threads.each do |thread|
  thread.join
end
