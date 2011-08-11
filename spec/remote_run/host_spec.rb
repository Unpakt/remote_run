require 'spec_helper'

describe Host do
  context "when locking" do
    let(:host) { Host.new("localhost") }

    it "can be locked" do
      host.lock.should be_true
    end

    it "cannot be locked twice" do
      host.lock.should be_true
      host.lock.should be_false
    end

    it "tells the lock file to get a lock" do
      host.lock
      `ssh localhost 'cat /tmp/remote-run-lock'`.strip.should == "#{$runner.local_hostname}-#{$runner.identifier}"
    end
  end

  context "when locked by someone else" do
    before { lock_file.get }
    let(:host) { Host.new("localhost") }
    let(:lock_file) {
      lock_file = Host::LockFile.new("localhost", "myfakelocalhost", "999")
    }

    it "cannot be unlocked by me" do
      host.unlock.should be_false
    end
  end

  context "when locked by me" do
    before { host.lock }
    let(:host) { Host.new("localhost") }

    it "cannot be locked" do
      host.lock.should be_false
    end

    it "can be unlocked" do
      host.unlock.should be_true
    end

    it "removes a file on the remote filesystem to unlock" do
      `ssh localhost 'test -e /tmp/remote-run-lock'; echo $?;`.strip.should == "0"
      host.unlock
      `ssh localhost 'test -e /tmp/remote-run-lock'; echo $?;`.strip.should == "1"
    end
  end

  context "when checking to see if a host is up" do
    context "when using an authorized host" do
      let(:host) { Host.new("localhost") }

      it "returns true" do
        host.is_up?.should be_true
      end
    end

    context "when using an unauthorized host" do
      let(:host) { Host.new("foozmcbarry") }

      it "returns false" do
        host.is_up?.should be_false
      end
    end
  end

  context "when running a task" do
    before do
      `ssh localhost 'rm -rf /tmp/testing-remote-run'`
      host.lock
    end

    let(:host) { Host.new("localhost") }

    context "when executing a shell command with a zero status code" do
      it "returns zero" do
        host.run("date > /dev/null").should == 0
      end
    end

    context "when executing a shell command with a non-zero status code" do
      it "returns non-zero status code" do
        host.run("cat /foo/bar 2>/dev/null").should_not == 0
      end
    end
  end

  describe "#copy_codebase" do
    before do
      `ssh localhost 'rm -rf /tmp/testing-remote-run'`
      host.lock
    end

    let(:host) { Host.new("localhost") }

    it "copies the codebase to a remote directory" do
      $runner.remote_path = "/tmp/testing-remote-run"
      `ssh localhost 'test -e /tmp/testing-remote-run'; echo $?`.strip.should_not == "0"
      host.copy_codebase
      `ssh localhost 'test -e /tmp/testing-remote-run'; echo $?`.strip.should == "0"
    end
  end
end

