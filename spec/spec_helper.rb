
require File.expand_path(File.dirname(__FILE__) + '/../lib/amazon/ecs')
require 'rubygems'
require 'bundler/setup'
require 'vcr_setup'
require "amazon_credentials"

RSpec.configure do |config|
  config.extend VCR::RSpec::Macros
end