module RemoteRun
  class Configuration
    attr_accessor :remote_path, :local_path, :login_as, :exclude, :temp_path, :quiet
    attr_reader :local_hostname, :identifier, :start_time
    attr_reader :host_manager, :task_manager

    def initialize
      @task_manager = TaskManager.new
      @host_manager = HostManager.new

      @local_path = Dir.getwd
      @login_as = `whoami`.strip
      @remote_path = "/tmp/remote"
      @exclude = []
      @temp_path = "/tmp/remote"
      @quiet = false
      @start_time = Time.now

      # used in the runner
      @identifier = `echo $RANDOM`.strip
      @local_hostname = `hostname`.strip

      $runner = self
      yield self
    end

    def hosts
      @host_manager.hosts
    end

    def tasks
      @task_manager.tasks
    end

    def hosts=(hostnames)
      hostnames.each do |hostname|
        @host_manager.add(Host.new(hostname))
      end
    end

    def tasks=(shell_commands)
      shell_commands.each do |shell_command|
        @task_manager.add(Task.new(shell_command))
      end
    end

    def run
      Runner.new(self).run
    end

    private

    class HostManager
      def initialize(&block)
        @hosts = []
      end

      def add(host)
        Thread.new do
          if host.is_up?
            @hosts << host
          end
        end
      end

      def hosts
        while @hosts.empty?
          sleep(0.5)
        end
        @hosts
      end

      def start_ssh_master_connections
        hosts.each do |host|
          host.start_ssh_master_connection
        end
      end
    end

    class TaskManager
      attr_reader :tasks

      def initialize
        @tasks = []
      end

      def add(task)
        @tasks.push(task)
      end

      def find_task
        @tasks.shift
      end

      def count
        @tasks.length
      end

      def has_more_tasks?
        @tasks.size > 0
      end
    end
  end
end
