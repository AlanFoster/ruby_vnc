# frozen_string_literal: true

require 'socket'
require 'logger'
require 'bindata'

class RubyVnc::Client
  SUPPORTED_VERSIONS = [
    RubyVnc::ProtocolVersion.new(3, 3),
    RubyVnc::ProtocolVersion.new(3, 8),
  ]

  module SecurityType
    INVALID            = 0
    NONE               = 1
    VNC_AUTHENTICATION = 2
    TIGHT              = 16
  end

  # The server supported security types
  # https://datatracker.ietf.org/doc/html/rfc6143#section-7.1.2
  class SecurityHandshake < BinData::Record
    endian :big

    # Number of security types
    # @!attribute [r] number_of_security_types
    #   @return [Integer]
    uint8 :number_of_security_types

    # The security types supported by the server
    # @!attribute [r] security_types
    #   @return [Array<Integer>]
    array :security_types, type: :uint8, initial_length: -> { number_of_security_types }
  end

  # The server handshake failure reason
  # https://datatracker.ietf.org/doc/html/rfc6143#section-7.1.2
  class SecurityHandshakeFailureReason < BinData::Record
    endian :big

    # the reason_string length
    # @!attribute [r] reason_length
    #   @return [Integer]
    uint32 :reason_length

    # The reason failure string
    # @!attribute [r] reason_string
    #   @return [String]
    string :reason_string, read_length: -> { reason_length }
  end

  # The client generated response to the security handshake
  # https://datatracker.ietf.org/doc/html/rfc6143#section-7.1.2
  class SecurityHandshakeResponse < BinData::Record
    endian :big

    # The security type accepted by the client
    # @!attribute [r] security_type
    #   @return [Integer]
    uint8 :security_type
  end

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

  def negotiate
    @socket ||= open_socket(host: host, port: port)

    # version handshake - https://datatracker.ietf.org/doc/html/rfc6143#section-7.1.1
    server_protocol_version_data = read(12).b
    logger.info("connected to remote server with protocol version #{server_protocol_version_data.inspect}")
    server_version = RubyVnc::ProtocolVersion.from_version_string(server_protocol_version_data)

    unless SUPPORTED_VERSIONS.include?(server_version)
      raise RubyVnc::Error::UnsupportedVersionError.new(server_protocol_version: server_protocol_version_data)
    end

    logger.debug('server version supported')
    write("#{server_version.to_version_string}\n")

    # security handshake - https://datatracker.ietf.org/doc/html/rfc6143#section-7.1.2
    handshake_data = read(1)
    number_of_security_types = handshake_data.unpack1('C')

    if number_of_security_types.zero?
      # Discard padding
      read(3)

      failure_data = read(4)
      failure_data_size = failure_data.unpack1('N')
      failure_data << read(failure_data_size)

      failure_reason = SecurityHandshakeFailureReason.read(failure_data)
      logger.error("Failed: #{failure_reason}")
      raise RubyVnc::Error::SecurityHandshakeFailure.new(failure_reason: failure_reason)
    end

    handshake_data << read(number_of_security_types)
    @handshake = SecurityHandshake.read(handshake_data)
    logger.debug("Security handshake: #{@handshake}")

    @handshake.security_types
  end

  def authenticate(security_type:, password: nil)
    # noop
  end

  protected

  # The non-blcoking socket that data will be written to/read from
  # @!attribute [r] logger
  #   @return [::Socket]
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

    socket
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
