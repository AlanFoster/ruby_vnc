# frozen_string_literal: true

# A RubyVnc Protocol version
class RubyVnc::ProtocolVersion
  # The major version
  # @!attribute [r] major
  #   @return [Integer]
  attr_reader :major

  # The minor version
  # @!attribute [r] minor
  #   @return [Integer]
  attr_reader :minor

  # @param [Integer] major version
  # @param [Integer] minor minor
  def initialize(major, minor)
    @major = major
    @minor = minor
  end

  # @param [string] string The server protocol version string
  # @return [RubyVnc::ProtocolVersion]
  def self.from_version_string(string)
    major_version, minor_version = string.match(/^RFB (\d{3})\.(\d{3})\n?$/)&.captures
    new(major_version.to_i, minor_version.to_i)
  end

  # @return [String] The version string without a trailing new line
  def to_version_string
    "RFB #{major.to_s.rjust(3, "0")}.#{minor.to_s.rjust(3, "0")}"
  end

  def ==(other)
    (major == other.major && minor == other.minor)
  end
end
