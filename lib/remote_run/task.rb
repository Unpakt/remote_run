module RemoteRun
  class Task
    attr_accessor :command, :pid, :host

    def initialize(command = nil)
      @command = command
    end
  end
end

