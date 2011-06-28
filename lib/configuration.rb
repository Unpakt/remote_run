class Configuration
  attr_accessor :remote_path, :local_path, :local_hostname, :hosts, :suites

  def initialize
    yield self
  end

  def local_hostname
    @local_hostname ||= `hostname`.strip
  end

  def identifier
    @identifier ||= `echo $RANDOM`.strip
  end

  def hosts=(hostnames)
    self.hosts = Hosts.new do |hosts|
      hostnames.each do |hostname|
        hosts.add(hostname)
      end
    end
  end

  def suites=(shell_commands)
    self.suites = Suites.new do |suite|
      shell_commands.each do |shell_command|
        suite.add(shell_command)
      end
    end
  end

  def run
    trap("SIGINT") do
      hosts.all.each do |host|
        host.unlock
      end
    end

    threads = []
    results = []

    while suites.more?
      host = hosts.free_host
      sleep(0.1)
      next unless host

      if host.lock
        suite = suites.find_suite
        threads << Thread.new do
          this_host = host.dup
          results << this_host.run(suite)
          this_host.unlock
        end
      end
    end

    threads.map(&:join)

    if results.all? { |result| result == true }
      puts "Suite passed."
    else
      puts "Suite failed."
    end
  end
end
