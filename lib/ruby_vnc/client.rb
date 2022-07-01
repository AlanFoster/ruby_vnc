require 'socket'
require 'logger'

class RubyVnc::Client
  def initialize(
      host: nil,
      port: 5900,
      socket: nil,
      logger: Logger.new(nil)
  )
    @host = host
    @port = port
    @socket = socket
    @logger = logger
  end

  def login(password: nil)
    @socket ||= open_socket(host: host, port: port)
  end

  protected

  # The non-blcoking socket that data will be written to/read from
  # @!attribute [r] logger
  #   @return [Socket]
  attr_reader :socket

  # The logger
  # @!attribute [r] logger
  #   @return [Logger]
  attr_reader :logger

  # The remote host address
  # @!attribute [r] logger
  #   @return [String]
  attr_reader :host

  # The remote host port
  # @!attribute [r] port
  #   @return [Integer]
  attr_reader :port

  def open_socket(host:, port:)
    socket = Socket.new(::Socket::AF_INET, ::Socket::SOCK_STREAM, 0)
    socket_addr = Socket.sockaddr_in(port, host)

    # Connect non-blocking, but block synchronously for a connection
    begin
      socket.connect_nonblock(socket_addr)
    rescue IO::WaitWritable
      # wait 3-way handshake completion
      IO.select(nil, [socket])
      begin
        socket.connect_nonblock(socket_addr) # check connection failure
      rescue Errno::EISCONN
        logger.info('connection opened')
      end
    end
  end
end
