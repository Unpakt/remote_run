class Runner
  attr_accessor :remote_path, :local_path, :local_hostname, :identifier, :login_as

  def initialize
    @identifier = `echo $RANDOM`.strip
    @local_hostname = `hostname`.strip
    @task_manager = TaskManager.new
    @host_manager = HostManager.new
    @local_path = Dir.getwd
    @login_as = `whoami`.strip
    @remote_path = "/tmp/remote/#{`hostname`.strip}"
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

  def run
    @host_manager.unlock_on_exit
    children = []

    timer = 0

    while @task_manager.has_more_tasks?
      sleep(1)
      timer += 1
      if timer == 15
        puts "#{@task_manager.all.size} tasks left."
        puts "#{@host_manager.unlocked_hosts.map(&:hostname).join(",")} are free."
        puts "#{@host_manager.locked_hosts.map(&:hostname).join(",")} are locked."
        puts "#{@host_manager.hosts_locked_by_me.map(&:hostname).join(",")} are locked by me."
        timer = 0
      end
      next unless host = @host_manager.free_host

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
      host = Host.new(hostname)
      if host.is_up?
        @hosts << host
      end
    end

    def free_host
      unlocked_hosts.first
    end

    def locked_hosts
      @hosts.select { |host| host.locked? }
    end

    def unlocked_hosts
      @hosts - locked_hosts
    end

    def hosts_locked_by_me
      @hosts.select { |host| host.locked_by_me? }
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

    def has_more_tasks?
      @tasks.size > 0
    end
  end
end
