# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'
require 'webmock/rspec'

require 'fcm'

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.expect_with :rspec do |c|
    c.syntax = %i[should expect]
  end
  # config.filter_run :focus
end
