module RemoteRun
  class Task
    attr_accessor :command

    def initialize(command)
      @command = command
    end
  end
end

