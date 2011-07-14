class Host
  FAIL = 1
  attr_reader :hostname

  def initialize(hostname)
    @hostname = hostname
    @lock = Lock.new(@hostname, $runner.local_hostname, $runner.identifier)
  end

  def lock
    @lock.get
    locked_by_me?
  end

  def unlock
    if locked_by_me?
      @lock.release
    end
  end

  def run(task)
    return FAIL unless copy_codebase
    run_task(task)
  end

  def locked?
    @lock.locked?
  end

  def locked_by_me?
    @lock.locked_by_me?
  end

  def is_up?
    result = `ssh -o ConnectTimeout=3 #{$runner.login_as}@#{@hostname} "echo 'success'"`.strip
    if result == "success"
      $highline.say($highline.color("#{@hostname} is up", :green))
      return true
    else
      $highline.say($highline.color("#{@hostname} is down: #{result}", :red))
      return false
    end
  end

  private

  def copy_codebase
    $highline.say($highline.color("Copying from #{$runner.local_path} to #{@hostname}:#{$runner.remote_path}", :yellow))
    system("ssh #{$runner.login_as}@#{@hostname} 'mkdir -p #{$runner.remote_path}'")
    excludes = $runner.rsync_exclude.map { |dir| "--exclude '#{dir}'"}
    if system("rsync --delete-excluded #{excludes.join(" ")} --exclude=.git --timeout=60 -a #{$runner.local_path}/ #{$runner.login_as}@#{@hostname}:#{$runner.remote_path}/")
      $highline.say($highline.color("Finished copying to #{@hostname}", :green))
      return true
    else
      $highline.say($highline.color("rsync failed on #{@hostname}.", :red))
      return false
    end
  end

  def run_task(task)
    $highline.say($highline.color("Running '#{task}' on #{@hostname}", :green))
    command = %Q{ssh #{$runner.login_as}@#{@hostname} 'cd #{$runner.remote_path}; #{task}' 2>&1}
    system(command)
    $?.exitstatus
  end

  class Lock
    FILE = "/tmp/remote-run-lock"

    def initialize(remote_hostname, local_hostname, unique_run_marker)
      @file = FILE
      @locker = "#{local_hostname}-#{unique_run_marker}"
      @remote_file = RemoteFile.new(remote_hostname)
    end

    def release
      if locked_by_me?
        @remote_file.delete(@file)
      end
    end

    def locked?
      @remote_file.exist?(@file)
    end

    def locked_by_me?
      @remote_file.exist?(@file) && @remote_file.read(@file).strip == @locker
    end

    def get
      unless locked?
        @remote_file.write(@file, @locker)
      end
    end

    class RemoteFile
      def initialize(hostname)
        @hostname = hostname
      end

      def exist?(file_path)
        `ssh #{$runner.login_as}@#{@hostname} 'test -f #{file_path}; echo $?'`.strip == "0"
      end

      def read(file_path)
        `ssh #{$runner.login_as}@#{@hostname} 'cat #{file_path} 2>/dev/null'`
      end

      def write(file_path, text)
        `ssh #{$runner.login_as}@#{@hostname} 'echo #{text} > #{file_path}'`
      end

      def delete(file_path)
        `ssh #{$runner.login_as}@#{@hostname} 'rm -f #{file_path}'`
      end
    end
  end
end

