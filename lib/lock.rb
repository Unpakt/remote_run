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
end
