require 'spec_helper'

describe RemoteRun::Runner do
  let(:host_manager) { double(:host_manager) }
  let(:task_manager) { double(:task_manager, count: 0) }
  let(:configuration) { double(:configuration, task_manager: task_manager, host_manager: host_manager) }
  subject { RemoteRun::Runner.new(configuration) }
  it { should be }

  describe "#start_ssh_master_connections" do
    it "should delegate to the host manager" do
      host_manager.should_receive(:start_ssh_master_connections)
      subject.start_ssh_master_connections
    end
  end
end
