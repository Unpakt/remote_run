class Host
  def initialize(hostname)
    @hostname = hostname
    @lock = Lock.new(@hostname, $runner.local_hostname, $runner.identifier)
  end

  def name
    @hostname
  end

  def lock
    @lock.get
    @lock.locked_by_me?
  end

  def unlock
    if @lock.locked_by_me?
      @lock.release
    end
  end

  def run(suite)
    copy_codebase
    run_suite(suite)
  end

  def locked?
    @lock.locked?
  end

  private

  def copy_codebase
    puts "Copying the codebase from #{$runner.local_path} to #{name}:#{$runner.remote_path}"
    system("ssh #{name} 'mkdir -p #{$runner.remote_path}'")
    system("rsync -a #{$runner.local_path}/ #{name}:#{$runner.remote_path}/")
  end

  def run_suite(suite)
    puts "Running '#{suite}' on #{name}"
    command = "ssh #{@hostname} 'cd #{$runner.remote_path}; #{suite}'"
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
        `ssh #{@hostname} 'test -f #{file_path}; echo $?'`.strip == "0"
      end

      def read(file_path)
        `ssh #{@hostname} 'cat #{file_path}'`
      end

      def write(file_path, text)
        `ssh #{@hostname} 'echo #{text} > #{file_path}'`
      end

      def delete(file_path)
        `ssh #{@hostname} 'rm #{file_path}'`
      end
    end
  end
end

