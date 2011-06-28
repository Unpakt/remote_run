class Runner
  attr_accessor :remote_path, :local_path, :local_hostname, :identifier

  def initialize
    @identifier = `echo $RANDOM`.strip
    @local_hostname = `hostname`.strip
    @task_manager = TaskManager.new
    @host_manager = HostManager.new
    $runner = self
    yield self
  end

  def self.run(&block)
    runner = new(&block)
    runner.run
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

  def run
    at_exit do
      duped_hosts = @host_manager.all.map { |host| host.dup }
      duped_hosts.each do |host|
        host.unlock
      end
    end

    children = []

    while @task_manager.more?
      host = @host_manager.free_host
      sleep(0.1)
      next unless host

      if host.lock
        task = @task_manager.find_task
        children << fork do
          this_host = host.dup
          status = this_host.run(task)
          this_host.unlock
          exit(status)
        end
      end
    end

    results = []
    while children.length > 0
      children.each do |child_pid|
        if Process.waitpid(child_pid, Process::WNOHANG)
          results << $?.exitstatus
          children.delete(child_pid)
        end
      end
    end

    if results.all? { |result| result == 0 }
      puts "Task passed."
    else
      puts "Task failed."
    end
  end

  class HostManager
    def initialize(&block)
      @hosts = []
    end

    def all
      @hosts
    end

    def add(hostname)
      @hosts << Host.new(hostname)
    end

    def free_host
      @hosts.select { |host| !host.locked? }.first
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

    def more?
      @tasks.size > 0
    end
  end
end
