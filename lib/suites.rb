class Suites
  def initialize(&block)
    @suites = []
    yield self
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

