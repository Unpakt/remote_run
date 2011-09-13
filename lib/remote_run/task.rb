module RemoteRun
  class Task
    attr_accessor :command, :pid

    def initialize(command)
      @command = command
    end
  end
end

