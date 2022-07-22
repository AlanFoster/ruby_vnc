# frozen_string_literal: true

autoload :Socket, 'socket'
autoload :Logger, 'logger'
autoload :BinData, 'bindata'

class RubyVnc::Client

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

  # Each request to the server has a specific message type that must be sent
  # https://datatracker.ietf.org/doc/html/rfc6143#section-7.5
  module ClientMessageType
    SET_PIXEL_FORMAT              = 0
    SET_ENCODINGS                 = 2
    FRAMEBUFFER_UPDATE_REQUEST    = 3
    KEY_EVENT                     = 4
    POINTER_EVENT                 = 5
    CLIENT_CUT_TEXT               = 6
  end

  # Each response from the server has a specific message type that must be sent
  # https://datatracker.ietf.org/doc/html/rfc6143#section-7.6
  module ServerMessageType
    FRAMEBUFFER_UPDATE     = 0
    SET_COLOR_MAP_ENTRIES  = 1
    BELL                   = 2
    SERVER_CUT_TEXT        = 3
  end

  # The encoding type for the framebuffer rectangle update received from the server
  # https://datatracker.ietf.org/doc/html/rfc6143#section-7.7
  module EncodingType
    # The raw bytes are sent for each rectangle update
    RAW                               = 0

    # Copy framebuffer data that already exists. Efficient for handling windows scrolling/moving
    COPY_RECT                         = 1

    # Rise and run length encoding
    RRE                               = 2

    HEXTILE                           = 5

    # Raw rectangles are decoded using a single zlib stream
    ZLIB                              = 6

    # TightVNC's encoding
    TIGHT                             = 7
    TRLE                              = 15
    ZRLE                              = 16
    CURSOR_PSEUDO_ENCODING            = -239
    DESKTOP_SIZE_PSEUDO_ENCODING      = -223
  end

  SUPPORTED_VERSIONS = [
    RubyVnc::ProtocolVersion.new(3, 3),
    RubyVnc::ProtocolVersion.new(3, 8),
  ].freeze

  SUPPORTED_ENCODINGS = [
    EncodingType::TIGHT,
    EncodingType::ZLIB,
    EncodingType::RAW
  ].freeze

  DEFAULT_ENCODINGS = SUPPORTED_ENCODINGS

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

  # Sent by the client to initialize a connection
  # https://datatracker.ietf.org/doc/html/rfc6143#section-7.3.1
  class ClientInit < BinData::Record
    endian :big

    # True if the server should try to share the
    # desktop by leaving other clients connected. False if it
    # should give exclusive access to this client by disconnecting all
    # other clients
    #
    # @!attribute [r] shared_flag
    #   @return [boolean]
    uint8 :shared_flag
  end

  # 16 byte structure describing the way a pixel is transmitted
  # https://datatracker.ietf.org/doc/html/rfc6143#section-7.4
  class PixelFormat < BinData::Record
    endian :big

    # the number of bits used for each pixel value on the wire
    # bits-per-pixel must be 8, 16, or 32
    # @!attribute [r] bit_per_pixel
    #   @return [Integer]
    uint8 :bits_per_pixel

    # the number of useful bits in the pixel value
    # @!attribute [r] bit_per_pixel
    #   @return [Integer]
    uint8 :depth

    # Big-endian-flag is non-zero (true) if multi-
    # byte pixels are interpreted as big endian.
    # @!attribute [r] big_endian_flag
    #   @return [Integer]
    uint8 :big_endian_flag

    # If true-color-flag is non-zero (true), then the last six items
    # specify how to extract the red, green, and blue intensities
    # from the pixel value
    # @!attribute [r] true_color_flag
    #   @return [Integer]
    uint8 :true_color_flag

    # maximum red value. Must be 2^N - 1, where N is the number of bits used for red
    # @!attribute [r] red_max
    #   @return [Integer]
    uint16 :red_max

    # @!attribute [r] green_max
    #   @return [Integer]
    uint16 :green_max

    # @!attribute [r] blue_max
    #   @return [Integer]
    uint16 :blue_max

    # @!attribute [r] red_shift
    #   @return [Integer]
    uint8 :red_shift

    # @!attribute [r] green_shift
    #   @return [Integer]
    uint8 :green_shift

    # @!attribute [r] blue_shift
    #   @return [Integer]
    uint8 :blue_shift

    # three bytes of padding
    # @!attribute [r] padding
    #   @return [Integer]
    uint24 :padding
  end

  # Sent by the server after a ClientInit call is made
  # https://datatracker.ietf.org/doc/html/rfc6143#section-7.3.2
  class ServerInit < BinData::Record
    endian :big

    # framebuffer-width in pixels
    #
    # @!attribute [r] framebuffer_width
    #   @return [Integer]
    uint16 :framebuffer_width

    # framebuffer-height in pixels
    #
    # @!attribute [r] framebuffer_height
    #   @return [Integer]
    uint16 :framebuffer_height

    # describes the way a pixel is transmitted
    #
    # @!attribute [r] pixel_format
    #   @return [Integer]
    pixel_format :pixel_format

    # the reason_string length
    # @!attribute [r] name_length
    #   @return [Integer]
    uint32 :name_length

    # The name associated with the desktop
    # @!attribute [r] reason_string
    #   @return [String]
    string :name_string, read_length: -> { name_length }
  end

  module KeyboardKey
    BACKSPACE           = 0xff08
    TAB                 = 0xff09
    RETURN              = 0xff0d
    ESCAPE              = 0xff1b
    INSERT              = 0xff63
    DELETE              = 0xffff
    HOME                = 0xff50
    END_KEY             = 0xff57
    PAGE_UP             = 0xff55
    PAGE_DOWN           = 0xff56
    LEFT                = 0xff51
    UP                  = 0xff52
    RIGHT               = 0xff53
    DOWN                = 0xff54
    F1                  = 0xffbe
    F2                  = 0xffbf
    F3                  = 0xffc0
    F4                  = 0xffc1
    F5                  = 0xffc2
    F6                  = 0xffc3
    F7                  = 0xffc4
    F8                  = 0xffc5
    F9                  = 0xffc6
    F10                 = 0xffc7
    F11                 = 0xffc8
    F12                 = 0xffc9
    SHIFT_LEFT          = 0xffe1
    SHIFT_RIGHT         = 0xffe2
    CONTROL_LEFT        = 0xffe3
    CONTROL_RIGHT       = 0xffe4
    META_LEFT           = 0xffe7
    META_RIGHT          = 0xffe8
    ALT_LEFT            = 0xffe9
    ALT_RIGHT           = 0xffea
  end

  # Sent by the client when there is a keyboard event
  # https://datatracker.ietf.org/doc/html/rfc6143#section-7.5.4
  class KeyboardEventRequest < BinData::Record
    endian :big

    # @!attribute [r] message_type
    #   @return [Integer]
    uint8 :message_type, initial_value: ClientMessageType::KEY_EVENT

    # @!attribute [r] :down_flag
    #   @return [Integer]
    uint8 :down_flag

    # @!attribute [r] padding
    #   @return [Integer]
    uint16 :padding

    # @!attribute [r] key
    #   @return [Integer]
    #   @see [RubyVnc::Client::KeyboardKey]
    uint32 :key_value
  end

  # the button mask index used as part of a pointer event
  # https://datatracker.ietf.org/doc/html/rfc6143#section-7.5.5
  module ButtonMask
    LEFT        = 0
    MIDDLE      = 1
    RIGHT       = 2
  end

  # Sent by the client when there is a pointer event, such as
  # movement/clicking
  # https://datatracker.ietf.org/doc/html/rfc6143#section-7.5.5
  class PointerEventRequest < BinData::Record
    endian :big

    # @!attribute [r] message_type
    #   @return [Integer]
    uint8 :message_type, initial_value: ClientMessageType::POINTER_EVENT

    # @!attribute [r] button_mask
    #   @return [Integer]
    uint8 :button_mask

    # @!attribute [r] x_position
    #   @return [Integer]
    uint16 :x_position

    # @!attribute [r] y_position
    #   @return [Integer]
    uint16 :y_position
  end

  # Sent by the client to set on the server the supported encoding types
  # https://datatracker.ietf.org/doc/html/rfc6143#section-7.5.1
  class SetPixelFormatRequest < BinData::Record
    endian :big

    # @!attribute [r] message_type
    #   @return [Integer]
    uint8 :message_type, initial_value: ClientMessageType::SET_PIXEL_FORMAT

    # three bytes of padding
    # @!attribute [r] padding
    #   @return [Integer]
    uint24 :padding

    # @!attribute [r] pixel_format
    #   @return [Integer]
    pixel_format :pixel_format
  end

  # Sent by the client to s et on the server the supported encoding types
  # https://datatracker.ietf.org/doc/html/rfc6143#section-7.5.2
  class SetEncodingsRequest < BinData::Record
    endian :big

    # @!attribute [r] message_type
    #   @return [Integer]
    uint8 :message_type, initial_value: ClientMessageType::SET_ENCODINGS

    # @!attribute [r] padding
    #   @return [Integer]
    uint8 :padding

    # @!attribute [r] number_of_encodings
    #   @return [Integer]
    uint16 :number_of_encodings, value: -> { self.encoding_types.length }

    # @!attribute [r] encoding_types
    #   @return [Array<Integer>]
    #   @see RubyVnc::Client::EncodingType
    array :encoding_types, type: :int32
  end

  # Sent by the client to request an update to the framebuffer within a
  # specific region
  # https://datatracker.ietf.org/doc/html/rfc6143#section-7.5.3
  class FramebufferUpdateRequest < BinData::Record
    endian :big

    # @!attribute [r] message_type
    #   @return [Integer]
    uint8 :message_type, initial_value: ClientMessageType::FRAMEBUFFER_UPDATE_REQUEST

    # If zero (false) this requests that the server send the entire
    # contents of the specified area as soon as possible.
    # @!attribute [r] incremental
    #   @return [Integer]
    uint8 :incremental

    # @!attribute [r] x_position
    #   @return [Integer]
    uint16 :x_position

    # @!attribute [r] y_position
    #   @return [Integer]
    uint16 :y_position

    # @!attribute [r] width
    #   @return [Integer]
    uint16 :width

    # @!attribute [r] height
    #   @return [Integer]
    uint16 :height
  end

  # Raw encoding update to the frame buffer
  # https://datatracker.ietf.org/doc/html/rfc6143#section-7.7.1
  class FramebufferUpdateRectangleRaw < BinData::Record
    endian :big

    # The raw pixel update
    # @!attribute [r] pixels
    #   @return [String]
    string :pixels, read_length: -> { width * height * client_state.bytes_per_pixel }
  end

  # Zlib encoding update to the frame buffer, which is a zlib compression of a raw rectangle update
  # https://github.com/rfbproto/rfbproto/blob/de8c2c73d85f7659af7dc750c34ccdadaa8b876b/rfbproto.rst#766zlib-encoding
  class FramebufferUpdateRectangleZlib < BinData::Record
    endian :big

    # @!attribute [r] length
    #   @return [Integer]
    uint32 :pixel_length

    # The raw pixel update
    # @!attribute [r] pixels
    #   @return [String]
    string :pixels, read_length: -> { pixel_length }
  end

  # Updates to the frame buffer
  # https://datatracker.ietf.org/doc/html/rfc6143#section-7.6.1
  class FramebufferUpdateRectangle < BinData::Record
    endian :big

    # @!attribute [r] x_position
    #   @return [Integer]
    uint16 :x_position

    # @!attribute [r] y_position
    #   @return [Integer]
    uint16 :y_position

    # @!attribute [r] width
    #   @return [Integer]
    uint16 :width

    # @!attribute [r] height
    #   @return [Integer]
    uint16 :height

    # @!attribute [r] encoding_type
    #   @return [Integer]
    int32 :encoding_type

    choice :body, selection: -> { encoding_type } do
      framebuffer_update_rectangle_raw EncodingType::RAW,
                                       width: -> { width },
                                       height: -> { height },
                                       client_state: -> { client_state }

      framebuffer_update_rectangle_zlib EncodingType::ZLIB

      framebuffer_update_rectangle_tight EncodingType::TIGHT,
                                         require: RubyVnc::Decoder::Tight,
                                         width: -> { width },
                                         height: -> { height }
    end
  end


  # Sent by the client to request an update to the framebuffer within a
  # specific region
  # https://datatracker.ietf.org/doc/html/rfc6143#section-7.6.1
  class FramebufferUpdate < BinData::Record
    endian :big

    # @!attribute [r] padding
    #   @return [Integer]
    uint8 :padding

    # @!attribute [r] number_of_rectangles
    #   @return [Integer]
    uint16 :number_of_rectangles

    # @!attribute [r] rectangles
    #   @return [Array<RubyVnc::Client::FramebufferRectangleUpdate>]
    array :rectangles, type: :framebuffer_update_rectangle, initial_length: -> { number_of_rectangles }
  end

  # Sent by the server when there is available cut text
  # https://datatracker.ietf.org/doc/html/rfc6143#section-7.6.4
  class ServerCutText < BinData::Record
    endian :big

    # @!attribute [r] padding
    #   @return [Integer]
    uint24 :padding

    # @!attribute [r] text_length
    #   @return [Integer]
    uint32 :text_length

    # The new ISO 8859-1 (Latin-1) text in its cut buffer. Ends of lines are represented by
    # the linefeed / newline character (value 10) alone. No carriage-return (value 13) is needed.
    #
    # @!attribute [r] pixels
    #   @return [String]
    string :text, read_length: -> { text_length }
  end

  # Wrapper class for server responses
  class ServerUpdate < BinData::Record
    # @!attribute [r] message_type
    #   @return [Integer]
    uint8 :message_type

    choice :body, selection: :message_type do
      framebuffer_update ServerMessageType::FRAMEBUFFER_UPDATE,
                         client_state: -> { client_state }

      server_cut_text ServerMessageType::SERVER_CUT_TEXT
    end
  end

  # A client update event
  class ClientUpdateEvent
    # the event type
    # @!attribute [r] type
    #   @return [symbol]
    attr_reader :type

    # the event body
    # @!attribute [r] body
    #   @return [Hash]
    attr_reader :body

    def initialize(type:, body: nil)
      @type = type
      @body = body
    end
  end

  class ClientState
    # @!attribute [r] bits_per_pixel
    #   @return [Integer]
    attr_reader :bits_per_pixel

    # @!attribute [r] width
    #   @return [Integer]
    attr_reader :width

    # @!attribute [r] height
    #   @return [Integer]
    attr_reader :height

    # @!attribute [rw] framebuffer
    #   @return [Array<Int>] The framebuffer array
    attr_accessor :framebuffer

    def initialize(
      bits_per_pixel:,
      width:,
      height:,
      framebuffer: nil
    )
      @framebuffer = framebuffer || RubyVnc::Framebuffer.new(width, height)
      @bits_per_pixel = bits_per_pixel
      @width = width
      @height = height
    end

    def bytes_per_pixel
      bits_per_pixel / 8
    end
  end

  # The client state, set after a successful init
  # @!attribute [rw] state
  #   @return [RubyVnc::Client::ClientState]
  attr_accessor :state

  def initialize(
    host: nil,
    port: 5900,
    socket: nil,
    logger: Logger.new(nil),
    encodings: DEFAULT_ENCODINGS
  )
    @host = host
    @port = port
    @socket = socket
    @logger = logger
    @encodings = encodings
    @decoders = {
      EncodingType::RAW => RubyVnc::Decoder::Raw.new,
      EncodingType::ZLIB => RubyVnc::Decoder::Zlib.new,
      EncodingType::TIGHT => RubyVnc::Decoder::Tight.new(logger: logger)
    }
  end

  # Negotiate with the server the available methods for authentication
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

  # Authenticate with the remote server
  def authenticate(security_type:, password: nil)
    unless handshake.security_types.include?(SecurityType::VNC_AUTHENTICATION)
      raise ::RubyVnc::Error::RubyVncError, 'security type not supported by server'
    end

    case security_type
      when SecurityType::NONE
        logger.info('Continuing with no authentication')
        true
      when SecurityType::VNC_AUTHENTICATION
        authenticate_with_vnc_authentication(password)
      else
        logger.error('Unknown error type')
        raise ::RubyVnc::Error::RubyVncError, 'security type not supported by client'
    end
  end

  # Use VNC Authentication
  # @param [String] password
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

  # Begins the initialization stage between teh client and server
  # @param [TrueClass] shared True if the server should try to share the
  #    desktop by leaving other clients connected. False if it
  #    should give exclusive access to this client by disconnecting all
  #    other clients
  def init(shared: true)
    logger.info('starting initialization stage')
    client_init = ClientInit.new(shared_flag: shared ? 1 : 0)
    socket.write(client_init.to_binary_s)

    server_init = ServerInit.read(socket)
    logger.info("server init response #{server_init}")

    set_pixel_format
    set_encodings

    @state = ClientState.new(
      bits_per_pixel: server_init.pixel_format.bits_per_pixel,
      width: server_init.framebuffer_width,
      height: server_init.framebuffer_height
    )
  end

  def set_pixel_format
    set_encodings_request = SetPixelFormatRequest.new(
      pixel_format: {
        bits_per_pixel: 32,
        depth: 24,
        big_endian_flag: 0,
        true_color_flag: 1,
        red_max: 255,
        green_max: 255,
        blue_max: 255,
        red_shift: 16,
        green_shift: 8,
        blue_shift: 0
      }
    )
    socket.write(set_encodings_request.to_binary_s)

    nil
  end

  # @param [Array<Number>] encoding_types
  # @return [nil]
  # @see [RubyVnc::Client::EncodingType]
  def set_encodings(encoding_types: @encodings)
    set_encodings_request = SetEncodingsRequest.new(
      encoding_types: encoding_types
    )
    socket.write(set_encodings_request.to_binary_s)

    nil
  end

  # @param [Integer] key_value
  def key_down(key_value)
    socket.write(
      KeyboardEventRequest.new(
        down_flag: 1,
        key_value: key_value
      ).to_binary_s
    )
    nil
  end

  # @param [Integer] key_valuekey
  def key_up(key_value)
    socket.write(
      KeyboardEventRequest.new(
        down_flag: 0,
        key_value: key_value
      ).to_binary_s
    )
    nil
  end

  # @param [Integer] x
  # @param [Integer] y
  # @return [nil]
  def move_pointer(x, y, pointer_state = nil)
    socket.write(
      PointerEventRequest.new(
        x_position: x,
        y_position: y,
        button_mask: as_button_mask(pointer_state)
      ).to_binary_s
    )

    nil
  end

  # @param [Integer] x
  # @param [Integer] y
  # @return [nil]
  def click_pointer(x, y, pointer_state = { left: true })
    socket.write(
      PointerEventRequest.new(
        x_position: x,
        y_position: y,
        button_mask: as_button_mask(pointer_state)
      ).to_binary_s
    )

    nil
  end

  def as_button_mask(pointer_state)
    mask = 0
    return mask if pointer_state.nil?

    mask |= (1 << ButtonMask::LEFT) if pointer_state[:left]
    mask |= (1 << ButtonMask::MIDDLE) if pointer_state[:middle]
    mask |= (1 << ButtonMask::RIGHT) if pointer_state[:right]
    mask
  end

  # Request a framebuffer update. The response will be sent asynchronously by the server.
  # @param [TrueClass,FalseClass] incremental
  # @return [nil]
  def request_framebuffer_update(incremental: true)
    logger.debug("sending frame buffer update request incremental=#{incremental}")
    request = FramebufferUpdateRequest.new(
      incremental: incremental ? 1 : 0,
      x_position: 0,
      y_position: 0,
      width: state.width,
      height: state.height
    )
    socket.write(request.to_binary_s)

    nil
  end

  # Attempts to poll for available framebuffer updates if they are available
  # @return [ClientUpdateEvent,nil] if there was an update, otherwise nil
  def poll_update
    ready_reads, _ready_writes, _ready_errors = IO.select([@socket], nil, nil, 0)
    return nil unless ready_reads

    read_update
  end

  # Blocks synchronously on reading the next update available from the server
  # @return [ClientUpdateEvent]
  def read_update
    update_response = ServerUpdate.read(
      socket,
      client_state: state
    )

    case update_response.message_type
    when ServerMessageType::FRAMEBUFFER_UPDATE
      decode_framebuffer_update(update_response.body)

      ClientUpdateEvent.new(type: :framebuffer_update)
    when ServerMessageType::SERVER_CUT_TEXT
      ClientUpdateEvent.new(
        type: :server_cut_text,
        body: {
          text: update_response.body.text
        }
      )
    else
      ClientUpdateEvent.new(
        type: :unknown,
        body: {
          message_type: update_response.message_type
        }
      )
    end
  end

  # Requests a framebuffer update, and blocks synchronously until the framebuffer can be updated.
  # The result is then saved to the given file path
  # @param [TrueClass, FalseClass] refresh When true the current framebuffer is refreshed from the remote server
  # @param [String] path the result path
  def screenshot(path:, refresh: true)
    request_framebuffer_update(incremental: false) if refresh

    # Note there may be an indefinite period of time before receiving the response
    logger.info('waiting for server frame buffer update')

    loop do
      event = read_update
      break if event.type == :framebuffer_update
    end

    logger.debug("saving to path #{path}")
    state.framebuffer.save(path)

    path
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

  # The list of encodings generated by the client to the server
  # @!attribute [rw] encodings
  #   @return [Array<Number>]
  #   @see [RubyVnc::Client::EncodingType]
  attr_accessor :encodings

  # The list of decoders registered with the current client
  # @!attribute [rw] decoders
  #   @return [Hash{Integer => RubyVnc::Decoder::Base}]
  #   @see [RubyVnc::Client::EncodingType]
  attr_accessor :decoders

  # def open_socket(host:, port:)
  #   socket = ::TcpSocket.openSocket.new(::Socket::AF_INET, ::Socket::SOCK_STREAM)
  #   socket_addr = ::Socket.sockaddr_in(port, host)
  #
  #   socket.connect(socket_addr)
  #   socket
  # end

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

  # @param [RubyVnc::Client::FramebufferUpdate] update
  def decode_framebuffer_update(update)
    logger.debug("Decoding rectangles #{update.rectangles.length}")
    update.rectangles.each do |rectangle|
      encoding_type = rectangle.body.selection
      decoder = decoders[encoding_type]

      if decoder
        decoder.decode(state, rectangle, state.framebuffer)
      else
        logger.error("unsupported encoding type #{encoding_type}")
      end
    end
  end
end
