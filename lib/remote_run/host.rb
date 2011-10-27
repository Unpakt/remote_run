module RemoteRun
  class Host
    FAIL = 1
    PASS = 0
    SSH_CONFIG = " -o NumberOfPasswordPrompts=0 -o StrictHostKeyChecking=no -4 "
    attr_reader :hostname

    def initialize(hostname)
      @hostname = hostname
      @lock_file = LockFile.new(@hostname, $runner.local_hostname, $runner.identifier)
    end

    def lock
      unless locked?
        @lock_file.get && locked_by_me?
      end
    end

    def unlock
      @lock_file.release
    end

    def run(task)
      command = %Q{ssh #{SSH_CONFIG} #{ssh_host_and_user} 'cd #{$runner.remote_path}; #{task}' 2>&1}
      system(command)
      $?.exitstatus
    end

    def copy_codebase
      system("ssh #{SSH_CONFIG} #{ssh_host_and_user} 'mkdir -p #{$runner.remote_path}'")
      excludes = $runner.exclude.map { |dir| "--exclude '#{dir}'"}
      if system(%{rsync --delete --delete-excluded #{excludes.join(" ")} --rsh='ssh #{SSH_CONFIG}' --timeout=60 -a #{$runner.temp_path}/ #{ssh_host_and_user}:#{$runner.remote_path}/})
        return true
      else
        return false
      end
    end

    def is_up?
      result = `ssh #{SSH_CONFIG} -o ConnectTimeout=2 #{ssh_host_and_user} "echo 'success'" 2>/dev/null`.strip
      if result == "success"
        return true
      else
        return false
      end
    end

    def start_ssh_master_connection
      fork do
        system("ssh #{SSH_CONFIG} #{ssh_host_and_user} -M &> /dev/null")
      end
    end

    private

    def ssh_host_and_user
      "#{$runner.login_as}@#{@hostname}"
    end

    def locked?
      @lock_file.locked?
    end

    def locked_by_me?
      @lock_file.locked_by_me?
    end

    class LockFile
      FILE = "/tmp/remote-run-lock"

      def initialize(remote_hostname, local_hostname, unique_run_marker)
        @filename = FILE
        @locker = "#{local_hostname}-#{unique_run_marker}"
        @remote_file = RemoteFile.new(remote_hostname)
      end

      def release
        if locked_by_me?
          @remote_file.delete(@filename)
        end
      end

      def locked?
        @remote_file.exist?(@filename)
      end

      def locked_by_me?
        @remote_file.exist?(@filename) && @remote_file.read(@filename).strip == @locker
      end

      def get
        @remote_file.write(@filename, @locker)
      end

      class RemoteFile
        def initialize(hostname)
          @hostname = hostname
        end

        def exist?(file_path)
          run_and_test("test -f #{file_path}")
        end

        def read(file_path)
          run("test -e #{file_path} && cat #{file_path}")
        end

        def write(file_path, text)
          run_and_test("test -e #{file_path} || echo #{text} > #{file_path}")
        end

        def delete(file_path)
          run_and_test("rm -f #{file_path}")
        end

        def run(command)
          `ssh #{Host::SSH_CONFIG} #{$runner.login_as}@#{@hostname} '#{command};'`.strip
        end

        def run_and_test(command)
          system("ssh #{Host::SSH_CONFIG} #{$runner.login_as}@#{@hostname} '#{command}' 2>/dev/null")
        end
      end
    end
  end
end

