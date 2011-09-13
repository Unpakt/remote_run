require 'spec_helper'

describe RemoteRun::Runner do
  let(:host_manager) { double(:host_manager) }
  let(:task_manager) { double(:task_manager, count: 0) }
  let(:configuration) { double(:configuration, task_manager: task_manager, host_manager: host_manager) }
  let(:runner) { RemoteRun::Runner.new(configuration) }
  subject { runner }
  it { should be }

  describe "#start_ssh_master_connections" do
    it "should delegate to the host manager" do
      host_manager.should_receive(:start_ssh_master_connections)
      runner.start_ssh_master_connections
    end
  end

  describe "#start_task" do
    let(:task) { RemoteRun::Task.new }
    let(:host) { double(:host) }
    let(:pid) { double(:pid) }
    before do
      runner.stub(:fork).and_return(pid)
      task_manager.stub(:find_task).and_return(task)
      runner.start_task(host)
    end
    describe "the task" do
      subject { task }
      its(:pid) { should == pid }
      its(:host) { should == host }
    end
  end
end
