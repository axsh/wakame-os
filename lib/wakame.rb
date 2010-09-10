# Wakame-OS (CLIOS - Cluster Level Infrastructure Operation System)
# Written by Yasuhiro Yamazaki. (y-yamazaki at axsh.net)
# Copyright (C) 2010 axsh co., LTD.
# License under GPL v2.

# require section
require 'rubygems'
$:.unshift(File.dirname(__FILE__))
require 'clios'

module Wakame
  include WakameOS::Client
end

# Initialize
Signal.trap(:EXIT) {
  WakameOS::Client::SystemCall.teardown
}
WakameOS::Client::SystemCall.setup
