class Host
  def initialize(name)
    @name = name
    @lock = Lock.new(name, $config.local_hostname, $config.identifier)
  end

  def name
    @name
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
    puts "Copying the codebase from #{$config.local_path} to #{name}:#{$config.remote_path}"
    system("ssh #{name} 'mkdir -p #{$config.remote_path}'")
    system("rsync -a #{$config.local_path}/ #{name}:#{$config.remote_path}/")
  end

  def run_suite(suite)
    puts "Running '#{suite}' on #{name}"
    command = "ssh #{@name} 'cd #{$config.remote_path}; #{suite}'"
    system(command)
  end
end

