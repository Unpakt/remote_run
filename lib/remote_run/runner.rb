class Runner
  attr_accessor :remote_path, :local_path, :local_hostname, :identifier, :login_as, :rsync_exclude

  def initialize
    @identifier = `echo $RANDOM`.strip
    @local_hostname = `hostname`.strip
    @task_manager = TaskManager.new
    @host_manager = HostManager.new
    @local_path = Dir.getwd
    @login_as = `whoami`.strip
    @rsync_exclude = []
    @timer = 0
    @remote_path = "/tmp/remote"
    @last_timestamp = Time.now.strftime("%S")[0]
    $runner = self
    yield self
  end

  def self.run(&block)
    runner = new(&block)
    runner.run
  end

  def hosts
    @host_manager.all
  end

  def hosts=(hostnames)
    hostnames.each do |hostname|
      @host_manager.add(hostname)
    end
  end

  def tasks=(shell_commands)
    shell_commands.each do |shell_command|
      @task_manager.add(shell_command)
    end
  end

  def display_task_status
    trying = "Trying #{@hosts.map(&:hostname).join(", ")}." unless @hosts.empty?
    display_status("\nWaiting on #{@task_manager.count} tasks to start. #{trying if trying}")
  end

  def display_pid_status
    display_status("\nWaiting on #{@children.length} tasks to finish. #{@children.inspect}")
  end

  def display_status(message)
    now = Time.now.strftime("%S")[0]
    unless now == @last_timestamp
      puts message
      @last_timestamp = now
    end
  end

  def run
    @host_manager.unlock_on_exit
    @children = []
    @hosts = []

    while @task_manager.has_more_tasks?
      @hosts = @host_manager.hosts.dup if @hosts.empty?
      display_task_status

      if host = @hosts.sample
        @hosts.delete(host)
        if host.lock
          puts "Locked #{host.hostname}."
          task = @task_manager.find_task
          @children << fork do
            this_host = host.dup
            status = this_host.run(task)
            host.unlock
            puts "Unlocked #{host.hostname}."
            exit(status)
          end
        else
          sleep(0.1)
        end
      end
    end

    results = []
    while @children.length > 0
      display_pid_status

      @children.each do |child_pid|
        if Process.waitpid(child_pid, Process::WNOHANG)
          results << $?.exitstatus
          @children.delete(child_pid)
        end
      end

      sleep(0.1)
    end

    if results.all? { |result| result == 0 }
      puts "Task passed."
    else
      puts "Task failed."
    end
  end

  private

  class HostManager
    def initialize(&block)
      @hosts = []
    end

    def all
      @hosts
    end

    def add(hostname)
      host = Host.new(hostname)
      if host.is_up?
        @hosts << host
      end
    end

    def hosts
      @hosts
    end

    def unlock_on_exit
      at_exit do
        duped_hosts = all.map { |host| host.dup }
        duped_hosts.each do |host|
          host.unlock
        end
      end
    end
  end

  class TaskManager
    def initialize
      @tasks = []
    end

    def add(script)
      @tasks.push(script)
    end

    def find_task
      @tasks.pop
    end

    def all
      @tasks
    end

    def count
      @tasks.length
    end

    def has_more_tasks?
      @tasks.size > 0
    end
  end
end
