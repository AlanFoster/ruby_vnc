# Simple wrapper that allows for an async socket to be
# read/written to sychronously
class RubyVnc::SynchronousReaderWriter
  def initialize(socket)
    @socket = socket
  end

  def read(len = 0)
    result = ''.b

    begin
      while result.length < len
        result << @socket.read_nonblock(len - result.length)
      end
    rescue IO::WaitReadable
      IO.select([@socket], [], [], 1)
      retry
    end

    result
  end

  def write(value)
    begin
      result = @socket.write_nonblock(value)
    rescue IO::WaitWritable, Errno::EINTR
      IO.select(nil, [@socket])
      retry
    end
    result
  end
end
