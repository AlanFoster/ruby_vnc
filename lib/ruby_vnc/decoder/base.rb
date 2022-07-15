# frozen_string_literal: true

autoload :Zlib, 'zlib'

# The base decoder which should be inherited from
class RubyVnc::Decoder::Base
  # @param [RubyVnc::Client::ClientState] state the current client state
  # @param [RubyVnc::Client::FramebufferUpdateRectangle] rectangle the parsed rectangle object
  # @param [Array<Integer>] framebuffer The current framebuffer of size width * height
  # @return [nil] The frame buffer should be directly mutated
  def decode(state, rectangle, framebuffer)
    raise NotImplementedError
  end
end
