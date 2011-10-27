module RemoteRun
  class Runner
    def initialize(configuration)
      @configuration = configuration
      @results = []
      @children = []
      @failed = []
      @stty_config = `stty -g`
      @last_timestamp = Time.now.strftime("%S")[0]
      @hosts = []

      @task_manager = @configuration.task_manager
      @host_manager = @configuration.host_manager
      @starting_number_of_tasks = @task_manager.count
    end

    def run
      setup_unlock_on_exit
      start_ssh_master_connections
      sync_working_copy_to_temp_location
      start_tasks
      wait_for_tasks_to_finish
      handle_results
    end

    def setup_unlock_on_exit
      at_exit do
        @configuration.hosts.each do |host|
          begin
            host.unlock
          rescue Errno::EPIPE
          end
        end
      end
    end

    def start_ssh_master_connections
      @host_manager.start_ssh_master_connections
    end

    def sync_working_copy_to_temp_location
      log("Creating temporary copy of #{@configuration.local_path} in #{@configuration.temp_path}...")
      excludes = @configuration.exclude.map { |dir| "--exclude '#{dir}'"}
      system("rsync --delete --delete-excluded #{excludes.join(" ")} -aq #{@configuration.local_path}/ #{@configuration.temp_path}/")
      log("Done.")
    end

    def start_tasks
      log("Starting tasks... #{Time.now}")

      while @task_manager.has_more_tasks?
        display_log
        check_for_finished
        find_lock_and_start
      end

      log("All tasks started... #{Time.now}")
    end

    def wait_for_tasks_to_finish
      while @children.length > 0
        sleep(1)
        display_log
        check_for_finished
      end
    end

    def handle_results
      failed_tasks = @results.select { |result| result != 0 }
      status_code = if failed_tasks.length == 0
        log("Task passed.", :green)
        Host::PASS
      else
        log("#{failed_tasks.length} task(s) failed.", :red)
        Host::FAIL
      end

      log("Total Time: #{run_time} minutes.")
      status_code
    end

    def start_task(host)
      task = @task_manager.find_task
      task.pid = fork do
        start_forked_task(host, task)
      end
      task.host = host
      @children << task
    end

    def start_forked_task(host, task)
      begin
        this_host = host.dup
        unless this_host.copy_codebase
          @task_manager.add(task)
          status = 0
        end
        status = this_host.run(task.command)
        host.unlock
      rescue Errno::EPIPE
      ensure
        Process.exit!(status)
      end
    end

    def find_lock_and_start
      @hosts = @host_manager.hosts.dup if @hosts.empty?
      if host = @hosts.sample
        @hosts.delete(host)
        if host.lock
          start_task(host)
        end
      end
    end

    def run_time
      minutes = ((Time.now - @configuration.start_time) / 60).to_i
      seconds = ((Time.now - @configuration.start_time) % 60).to_i
      "#{minutes}:#{"%02d" % seconds}"
    end

    def log(message, color = :yellow)
      unless @configuration.quiet
        highline = HighLine.new
        system("stty #{@stty_config} 2>/dev/null")
        highline.say(highline.color("[Remote :: #{@configuration.identifier} :: #{run_time}] #{message}", color))
      end
    end

    def check_for_finished
      @children.each do |task|
        child_pid = task.pid
        if task_is_finished?(child_pid)
          @results << $?.exitstatus
          @children.delete(task)
        end
      end
    end

    def task_is_finished?(pid)
      Process.waitpid(pid, Process::WNOHANG)
    end

    def display_log
      now = Time.now.strftime("%M")[0]
      unless now == @last_timestamp
        log("Waiting on #{@task_manager.count} of #{@starting_number_of_tasks} tasks to start.") if @task_manager.count > 0
        log("Waiting on #{@children.length} of #{@starting_number_of_tasks - @task_manager.count} started tasks to finish. #{@failed.size} failed.") if @children.length > 0
        $stdout.flush
        @last_timestamp = now
      end
    end
  end
end
