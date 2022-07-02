module RubyVnc::Error
  class RubyVncError < StandardError; end

  # The remote server version is unsupported
  class UnsupportedVersionError < RubyVncError
    # The server protocol version string
    # @!attribute [r] server_protocol_version
    #   @return [String]
    attr_reader :server_protocol_version

    def initialize(message: nil, server_protocol_version:)
      super(message || "Unsupported server protocol version '#{server_protocol_version.chomp}'")
      @server_protocol_version = server_protocol_version
    end
  end

  # The security handshake failed
  class SecurityHandshakeFailure < RubyVncError
    # The parsed reason for failure
    # @!attribute [r] server_protocol_version
    #   @return [RubyVnc::Client::SecurityHandshakeFailureReason]
    attr_reader :failure_reason

    # @param [string,nil] message
    # @param [RubyVnc::Client::SecurityHandshakeFailureReason] failure_reason
    def initialize(message: nil, failure_reason:)
      message ||= "Security handshake failed '#{failure_reason&.reason_string || 'No given reason'}'"
      super(message)
      @failure_reason = failure_reason
    end
  end
end
