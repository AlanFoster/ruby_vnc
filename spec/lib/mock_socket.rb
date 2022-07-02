class MockSocket
  def initialize(data)
    @read_data = data || ''
    @write_data = ''
  end

  def read_nonblock(n)
    result, remaining = @read_data[0...n], @read_data[n..-1]
    @read_data = remaining || ''
    result
  end

  def write_nonblock(value)
    @write_data << value
  end
end
