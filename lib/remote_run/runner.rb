module RemoteRun
  class Runner
    def initialize(configuration)
      @configuration = configuration
      @results = []
      @children = []
      @failed = []
      @stty_config = `stty -g`
      @last_timestamp = Time.now.strftime("%S")[0]

      @task_manager = @configuration.task_manager
      @host_manager = @configuration.host_manager
    end

    def unlock_on_exit
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
      @configuration.hosts.each do |host|
        host.start_ssh_master_connection
      end
    end

    def run
      unlock_on_exit
      start_ssh_master_connections
      sync_working_copy_to_temp_location
      hosts = []

      log("Starting tasks... #{Time.now}")

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
              begin
                this_host = host.dup
                unless this_host.copy_codebase
                  @task_manager.add(task)
                  status = 0
                end
                status = this_host.run(task.command)
                host.unlock
                log("#{host.hostname} failed.", :red) if status != 0
              rescue Errno::EPIPE
                log("broken pipe on #{host.hostname}...")
              ensure
                Process.exit!(status)
              end
            end
          end
        end
      end

      log("All tasks started... #{Time.now}")

      while @children.length > 0
        display_log
        check_for_finished
      end

      failed_tasks = @results.select { |result| result != 0 }
      status_code = if failed_tasks.length == 0
        log("Task passed.", :green)
        Host::PASS
      else
        log("#{failed_tasks.length} task(s) failed.", :red)
        Host::FAIL
      end

      log("Total Time: #{self.run_time} minutes.")
      status_code
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

    def sync_working_copy_to_temp_location
      log("Creating temporary copy of #{@configuration.local_path} in #{@configuration.temp_path}...")
      excludes = @configuration.exclude.map { |dir| "--exclude '#{dir}'"}
      system("rsync --delete --delete-excluded #{excludes.join(" ")} -aq #{@configuration.local_path}/ #{@configuration.temp_path}/")
      log("Done.")
    end

    def display_log
      now = Time.now.strftime("%S")[0]
      unless now == @last_timestamp
        display_status("Waiting on #{@task_manager.count} of #{@starting_number_of_tasks} tasks to start.") if @task_manager.count > 0
        display_status("Waiting on #{@children.length} of #{@starting_number_of_tasks - @task_manager.count} started tasks to finish. #{@failed.size} failed.") if @children.length > 0
        $stdout.flush
        @last_timestamp = now
      end
    end

    def display_status(message)
      log(message, :yellow)
    end
  end
end

