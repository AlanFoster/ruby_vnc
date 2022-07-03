# frozen_string_literal: true

require 'socket'
require 'logger'
require 'bindata'

class RubyVnc::Client
  SUPPORTED_VERSIONS = [
    RubyVnc::ProtocolVersion.new(3, 3),
    RubyVnc::ProtocolVersion.new(3, 8),
  ].freeze

  # https://datatracker.ietf.org/doc/html/rfc6143#section-8.1.2
  module SecurityType
    INVALID            = 0
    NONE               = 1
    VNC_AUTHENTICATION = 2
    TIGHT              = 16
    ULTRA              = 17
    VENCRYPT           = 19
  end

  # https://datatracker.ietf.org/doc/html/rfc6143#section-7.1.3
  module SecurityResult
    OK                = 0
    FAILED            = 1
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

  # Send from the server for the client to use as part of encryption
  # https://datatracker.ietf.org/doc/html/rfc6143#section-7.2.2
  class VncAuthenticationChallenge < BinData::Record
    endian :big

    # The challenge generated by the server
    # @!attribute [r] challenge
    #   @return [string]
    string :challenge, length: 16
  end

  # Sent from the client to the server
  # https://datatracker.ietf.org/doc/html/rfc6143#section-7.2.2
  class VncAuthenticationChallengeResponse < BinData::Record
    endian :big

    # The response generated by the client
    # @!attribute [r] response
    #   @return [string]
    string :response, length: 16
  end

  # Sent from the server to the client
  # https://datatracker.ietf.org/doc/html/rfc6143#section-7.2.2
  class VncAuthenticationResult < BinData::Record
    endian :big

    # Whather or not the security handshake was successful
    # @!attribute [r] status
    #   @return [Integer]
    uint32 :status
  end

  # Sent from the server to the client on authentication failure
  # https://datatracker.ietf.org/doc/html/rfc6143#section-7.2.2
  class VncAuthenticationFailureReason < BinData::Record
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
    server_protocol_version_data = socket.read(12)
    logger.info("connected to remote server with protocol version #{server_protocol_version_data.inspect}")
    server_version = RubyVnc::ProtocolVersion.from_version_string(server_protocol_version_data)

    unless SUPPORTED_VERSIONS.include?(server_version)
      raise RubyVnc::Error::UnsupportedVersionError.new(server_protocol_version: server_protocol_version_data)
    end

    logger.debug('server version supported')
    socket.write("#{server_version.to_version_string}\n")

    # security handshake - https://datatracker.ietf.org/doc/html/rfc6143#section-7.1.2
    handshake_data = socket.read(1)
    number_of_security_types = handshake_data.unpack1('C')

    if number_of_security_types.zero?
      # Discard padding
      socket.read(3)

      failure_reason = SecurityHandshakeFailureReason.read(socket)
      logger.error("Failed: #{failure_reason}")
      raise RubyVnc::Error::SecurityHandshakeFailure.new(failure_reason: failure_reason)
    end

    handshake_data << socket.read(number_of_security_types)
    self.handshake = SecurityHandshake.read(handshake_data)
    logger.debug("Security handshake: #{@handshake}")

    handshake.security_types
  end

  def authenticate(security_type:, password: nil)
    unless handshake.security_types.include?(SecurityType::VNC_AUTHENTICATION)
      raise ::RubyVnc::Error::RubyVncError, 'security type not supported by server'
    end

    case security_type
      when SecurityType::NONE
        logger.info('Continuing with no authentication')
      when SecurityType::VNC_AUTHENTICATION
        authenticate_with_vnc_authentication(password)
      else
        logger.error('Unknown error type')
        raise ::RubyVnc::Error::RubyVncError, 'security type not supported by client'
    end
  end

  def authenticate_with_vnc_authentication(password)
    logger.info('authenticating with VNC_AUTHENTICATION')

    response = SecurityHandshakeResponse.new(
      security_type: SecurityType::VNC_AUTHENTICATION
    )
    socket.write(response.to_binary_s)

    challenge_packet = VncAuthenticationChallenge.read(socket)
    response = VncAuthenticationChallengeResponse.new(
      response: RubyVnc::Crypto.des(challenge_packet.challenge, password)
    )
    socket.write(response.to_binary_s)

    authentication_result = VncAuthenticationResult.read(socket)

    # Handle the authentication status code
    case authentication_result.status
    when SecurityResult::OK
      logger.info('successfully authenticated')
      true
    when SecurityResult::FAILED
      failure_reason = VncAuthenticationFailureReason.read(socket)
      logger.info("failed authentication - #{failure_reason}")

      false
    else
      logger.info("unknown status code #{authentication_result.status} did not successfully authenticate")

      false
    end
  end

  protected

  # The non-blocking socket that data will be written to/read from
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

  # The security handshake data returned by the remote server
  # @!attribute [rw] handshake
  #   @return [RubyVnc::Client::SecurityHandshake]
  attr_accessor :handshake

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

    RubyVnc::SynchronousReaderWriter.new(socket)
  end
end
