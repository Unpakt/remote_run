require 'spec_helper'

describe RemoteRun::Task do
  let(:command) { double(:command) }
  subject { RemoteRun::Task.new(command) }
  it { should be }
  its(:command) { should == command }

  describe "pid attribute" do
    let(:pid) { double(:pid) }
    before { subject.pid = pid }
    its(:pid) { should == pid }
  end

  describe "host attribute" do
    let(:host) { double(:host) }
    before { subject.host = host }
    its(:host) { should == host }
  end
end
