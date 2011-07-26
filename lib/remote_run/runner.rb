class Runner
  attr_accessor :remote_path, :local_path, :login_as, :rsync_exclude, :logging, :temp_path
  attr_reader :local_hostname, :identifier
  @@start_time = Time.now

  def initialize
    @task_manager = TaskManager.new
    @host_manager = HostManager.new

    # config options
    @identifier = `echo $RANDOM`.strip
    @local_hostname = `hostname`.strip
    @local_path = Dir.getwd
    @login_as = `whoami`.strip
    @remote_path = "/tmp/remote"
    @rsync_exclude = []
    @temp_path = "/tmp/remote"

    # used in the runner
    @results = []
    @children = []
    @failed = []
    @last_timestamp = Time.now.strftime("%S")[0]

    $runner = self
    yield self
  end

  def self.run(&block)
    @@start_time = Time.now
    runner = new(&block)
    runner.run
  end

  def self.run_time
    minutes = ((Time.now - @@start_time) / 60).to_i
    seconds = ((Time.now - @@start_time) % 60).to_i
    "#{minutes}:#{"%02d" % seconds}"
  end

  def self.log(message, color = :yellow)
    highline = HighLine.new
    highline.say(highline.color("[Remote #{run_time}] #{message}", color))
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
    sync_working_copy_to_temp_location
    hosts = []

    Runner.log("Starting tasks... #{Time.now}")

    @starting_number_of_tasks = @task_manager.count
    while @task_manager.has_more_tasks?
      hosts = @host_manager.hosts.dup if hosts.empty?

      display_log
      check_for_finished

      if host = hosts.sample
        hosts.delete(host)
        if host.lock
          task = @task_manager.find_task
          @children << fork do
            this_host = host.dup
            status = this_host.run(task)
            host.unlock
            Runner.log("#{host.hostname} failed.", :red) if status != 0
            Process.exit!(status)
          end
        end
      end
    end

    Runner.log("All tasks started... #{Time.now}")

    while @children.length > 0
      display_log
      check_for_finished
    end

    failed_tasks = @results.select { |result| result != 0 }
    status_code = if failed_tasks.length == 0
      Runner.log("Task passed.", :green)
      Host::PASS
    else
      Runner.log("#{failed_tasks.length} task(s) failed.", :red)
      Host::FAIL
    end

    Runner.log("Total Time: #{self.class.run_time} minutes.")
    status_code
  end

  def check_for_finished
    @children.each do |child_pid|
      if Process.waitpid(child_pid, Process::WNOHANG)
        if $?.exitstatus != 0
          @failed << child_pid
        end

        @results << $?.exitstatus
        @children.delete(child_pid)
      end
    end
    sleep(0.5)
  end

  private

  def sync_working_copy_to_temp_location
    Runner.log("Creating temporary copy of #{@local_path} in #{@temp_path}...")
    system("rsync -a #{@local_path}/ #{@temp_path}/")
    Runner.log("Done.")
  end

  def display_log
    now = Time.now.strftime("%S")[0]
    unless now == @last_timestamp
      display_status("Waiting on #{@task_manager.count} of #{@starting_number_of_tasks} tasks to start.") if @task_manager.count > 0
      display_status("Waiting on #{@children.length} of #{@starting_number_of_tasks - @task_manager.count} started tasks to finish. #{@failed.size} failed.") if @children.length > 0
      $stdout.print("\n\n")
      $stdout.flush
      @last_timestamp = now
    end
  end

  def display_status(message)
    Runner.log(message, :yellow)
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
      Thread.new do
        if host.is_up?
          @hosts << host
        end
      end
    end

    def hosts
      while @hosts.empty?
        Runner.log("Waiting for hosts...")
        sleep(0.5)
      end

      @hosts
    end

    def unlock_on_exit
      at_exit do
        duped_hosts = all.map { |host| host.dup }
        duped_hosts.each do |host|
          begin
            host.unlock
          rescue Exception
          end
        end
      end
    end

    def clean_up_ssh_connections
      begin
        system("ps aux | grep ControlMaster | awk '{ print $2;}' | xargs kill")
      rescue Exception
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
      @tasks.shift
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
