class Hosts
  def initialize(&block)
    @hosts = []
    yield self
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

