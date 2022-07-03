# Simple wrapper that allows for an async socket to be
# read/written to sychronously
class RubyVnc::SynchronousReaderWriter
  def initialize(socket)
    @socket = socket
  end

  def read(maxlen = 65_536)
    begin
      result = @socket.read_nonblock(maxlen)
    rescue IO::WaitReadable
      IO.select([@socket])
      retry
    end

    result
  end

  def write(value)
    begin
      result = @socket.write_nonblock(value)
    rescue IO::WaitWritable, Errno::EINTR
      IO.select(nil, [io])
      retry
    end
    result
  end
end
