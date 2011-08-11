# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "remote_run/version"

Gem::Specification.new do |s|
  s.name        = "remote_run"
  s.version     = RemoteRun::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Case Commons, LLC"]
  s.email       = ["casecommons-dev@googlegroups.com"]
  s.homepage    = "https://github.com/Casecommons/remote_run"
  s.summary     = %q{Run N shell scripts on a pool of remote hosts}
  s.description = %q{Can be used as a parallel unit test runner}

  s.rubyforge_project = "remote_run"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.add_runtime_dependency("highline")
  s.add_development_dependency('rspec')
end
