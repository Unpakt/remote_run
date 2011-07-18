require 'rubygems'
require 'bundler/setup'
require 'rspec'
require Dir.pwd + '/lib/remote_run'

Runner.new do |config|
  config.tasks = []
  config.hosts = []
  config.logging = false
end

RSpec.configure do |config|
  config.after(:each) do
    system("rm -f #{Host::LockFile::FILE}")
  end
end
