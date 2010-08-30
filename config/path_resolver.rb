# -*- coding: utf-8 -*-

begin
  require File.expand_path('../../.bundle/environment', __FILE__)
rescue LoadError => e
  require 'rubygems'
end
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift File.expand_path('../../config', __FILE__)

version = ">= 0"

if ARGV.first =~ /^_(.*)_$/ and Gem::Version.correct? $1 then
  version = $1
  ARGV.shift
end

begin
  gem 'clios', version
rescue Gem::LoadError => e
  require 'clios'
end
require 'cloud_catalog'
