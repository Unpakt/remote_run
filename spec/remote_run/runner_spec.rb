require 'spec_helper'

describe RemoteRun::Runner do
  let(:host_manager) { double(:host_manager) }
  let(:task_manager) { double(:task_manager, count: 0) }
  let(:configuration) { double(:configuration, task_manager: task_manager, host_manager: host_manager) }
  subject { RemoteRun::Runner.new(configuration) }
  it { should be }

  describe "#run" do
    before do
      subject.stub(:setup_unlock_on_exit)
      subject.stub(:sync_working_copy_to_temp_location)
      subject.stub(:start_tasks)
      subject.stub(:handle_results)
    end

    it "should start ssh connections" do
      host_manager.should_receive(:start_ssh_master_connections)
      subject.run
    end
  end
end
