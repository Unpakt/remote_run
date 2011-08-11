require 'rubygems'
require 'bundler/setup'
require 'rspec'
require Dir.pwd + '/lib/remote_run'

RemoteRun::Configuration.new do |config|
  config.tasks = []
  config.hosts = []
  config.quiet = true
end

RSpec.configure do |config|
  config.after(:each) do
    system("rm -f #{RemoteRun::Host::LockFile::FILE}")
  end
end
