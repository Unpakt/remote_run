class Host
  FAIL = 1
  attr_reader :hostname
  attr_reader :lock_file

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
    return FAIL unless copy_codebase
    run_task(task)
  end

  def is_up?
    result = `ssh -o ConnectTimeout=3 #{$runner.login_as}@#{@hostname} "echo 'success'" 2>/dev/null`.strip
    if result == "success"
      Runner.log("#{@hostname} is up", :green)
      return true
    else
      Runner.log("#{@hostname} is down: #{result}", :red)
      return false
    end
  end

  private

  def locked?
    @lock_file.locked?
  end

  def locked_by_me?
    @lock_file.locked_by_me?
  end

  def copy_codebase
    Runner.log("Copying from #{$runner.local_path} to #{@hostname}:#{$runner.remote_path}", :yellow)
    system("ssh #{$runner.login_as}@#{@hostname} 'mkdir -p #{$runner.remote_path}'")
    excludes = $runner.rsync_exclude.map { |dir| "--exclude '#{dir}'"}
    if system("rsync --delete-excluded #{excludes.join(" ")} --exclude=.git --timeout=60 -a #{$runner.local_path}/ #{$runner.login_as}@#{@hostname}:#{$runner.remote_path}/")
      Runner.log("Finished copying to #{@hostname}", :green)
      return true
    else
      Runner.log("rsync failed on #{@hostname}.", :red)
      return false
    end
  end

  def run_task(task)
    Runner.log("Running '#{task}' on #{@hostname}", :white)
    command = %Q{ssh #{$runner.login_as}@#{@hostname} 'cd #{$runner.remote_path}; #{task}' 2>&1}
    system(command)
    $?.exitstatus
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
        run("cat #{file_path}")
      end

      def write(file_path, text)
        run_and_test("test -e #{file_path} || echo #{text} > #{file_path}")
      end

      def delete(file_path)
        run_and_test("rm -f #{file_path}")
      end

      def run(command)
        `ssh #{$runner.login_as}@#{@hostname} '#{command};'`.strip
      end

      def run_and_test(command)
        `ssh #{$runner.login_as}@#{@hostname} '#{command}; echo $?'`.strip == "0"
      end
    end
  end
end

