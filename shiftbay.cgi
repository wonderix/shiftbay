#!/usr/local/bin/ruby
 
require "rubygems"
require "rack"
require "/opt/home/kramer/sources/shiftbay/shift.rb"
 
Rack::Handler::CGI.run(ShiftbayApp)
