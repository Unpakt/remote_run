
class Runner
  attr_accessor :remote_path, :local_path, :local_hostname, :identifier

  def initialize
    hostname = `hostname`.strip
    identifier = `echo $RANDOM`.strip

    @identifier = identifier
    @local_hostname = hostname
    @suite_manager = SuiteManager.new
    @host_manager = HostManager.new
    $runner = self
    yield self

    raise "must have a remote path set: e.g. config.remote_path = '~/workspace/cool-project'" unless remote_path
    raise "must have a local path set: e.g. config.local_path = '~/workspace/cool-project'" unless local_path
  end

  def hosts=(hostnames)
    hostnames.each do |hostname|
      @host_manager.add(hostname)
    end
  end

  def suites=(shell_commands)
    shell_commands.each do |shell_command|
      @suite_manager.add(shell_command)
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
    while @suite_manager.more?
      host = @host_manager.free_host
      sleep(0.1)
      next unless host

      if host.lock
        suite = @suite_manager.find_suite
        children << fork do
          this_host = host.dup
          status = this_host.run(suite)
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
      puts "Suite passed."
    else
      puts "Suite failed."
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

  class SuiteManager
    def initialize
      @suites = []
    end

    def add(script)
      @suites.push(script)
    end

    def find_suite
      @suites.pop
    end

    def more?
      @suites.size > 0
    end
  end
end
