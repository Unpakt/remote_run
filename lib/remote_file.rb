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
