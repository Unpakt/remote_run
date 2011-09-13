require 'spec_helper'

describe RemoteRun::Configuration::HostManager do
  let(:host) { double(:host, is_up?: true, name: "foobar") }
  subject { RemoteRun::Configuration::HostManager.new }

  describe "#add" do
    it "adds the given host to a list of hosts" do
      subject.add(host)
      subject.hosts.size.should == 1
      subject.hosts.first.name.should == "foobar"
    end
  end

  describe "#hosts" do
    it "returns all hosts in the list" do
      subject.add(host)
      subject.hosts.should == [host]
    end
  end

  describe "#start_ssh_master_connections" do
    before do
      subject.add(host)
    end

    it "asks each host to start their ssh master connection" do
      host.should_receive(:start_ssh_master_connection)
      subject.start_ssh_master_connections
    end
  end
end

describe RemoteRun::Configuration::TaskManager do
  subject { RemoteRun::Configuration::TaskManager.new }
  describe "#add" do
    it "takes a string and puts it on a list of tasks" do
      task = RemoteRun::Task.new("date")
      subject.add(task)
      subject.tasks.should include(task)
    end
  end

  describe "#find_task" do
    before do
      @task = RemoteRun::Task.new("date")
      subject.add(@task)
    end

    it "finds a task from the list, returns it and removes it" do
      subject.tasks.should == [@task]
      subject.find_task.should == @task
      subject.tasks.should == []
    end
  end

  describe "#tasks" do
    it "returns all of the tasks stored in the manager" do
      task = RemoteRun::Task.new("foo")
      task2 = RemoteRun::Task.new("bar")
      subject.add(task)
      subject.add(task2)
      subject.tasks.should == [task, task2]
    end
  end

  describe "#count" do
    it "returns the number of tasks stored" do
      task = RemoteRun::Task.new("foo")
      task2 = RemoteRun::Task.new("bar")
      subject.add(task)
      subject.add(task2)
      subject.count.should == 2
    end
  end

  describe "#has_more_tasks?" do
    it "returns true when there are tasks in the list" do
      task = RemoteRun::Task.new("foo")
      task2 = RemoteRun::Task.new("bar")
      subject.add(task)
      subject.add(task2)

      subject.has_more_tasks?.should be_true
      subject.find_task
      subject.has_more_tasks?.should be_true
      subject.find_task
      subject.has_more_tasks?.should be_false
    end
  end
end
