require 'spec_helper'

describe "Remote Run" do
  let(:passing_script) do
    <<-SCRIPT
      require 'rubygems'
      require 'bundler/setup'
      require 'remote_run'

      runner = RemoteRun::Configuration.new do |config|
        config.hosts = ["localhost"]
        config.tasks = ["#{task}"]
      end
      runner.run
    SCRIPT
  end

  let(:script_path) { "/tmp/remote-run-test" }
  require 'timeout'

  context "when the remote run should pass" do
    let(:task) { "echo 'sometext'" }
    before do
      File.open(script_path, "w+") do |file|
        file.write(passing_script)
      end
      FileUtils.chmod(0700, script_path)
    end

    def execute_script
      result = {
        output: nil,
        status: nil
      }

      pid = nil
      begin
        Timeout.timeout(5) do
          # system("ruby #{script_path}")
          IO.popen("ruby #{script_path}") do |io|
            pid = io.pid
            result[:output] = io.read
          end
          result[:status] = $?.exitstatus
        end
      ensure
        # Make sure the process dies.
        begin
          Process.kill("TERM", pid)
          Process.wait(pid)
        rescue Errno::ESRCH
          # Process is already dead.
        end
      end

      result
    end

    describe "Running a full run" do
      it "has a passing exit code" do
        execute_script[:status].should == 0
      end

      it "prints sometext as a result of echo" do
        execute_script[:output].should include('sometext')
      end
    end
  end
end
