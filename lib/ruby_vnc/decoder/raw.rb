# frozen_string_literal: true

# The Raw decoder which implements decoding https://datatracker.ietf.org/doc/html/rfc6143#section-7.7.1
class RubyVnc::Decoder::Raw < RubyVnc::Decoder::Base
  # @param [RubyVnc::Client::ClientState] state the current client state
  # @param [RubyVnc::Client::FramebufferUpdateRectangle] rectangle the parsed rectangle object
  # @param [Array<Integer>] framebuffer The current framebuffer of size width * height
  # @return [nil] The frame buffer should be directly mutated
  def decode(state, rectangle, framebuffer)
    pixel_string = rectangle.body.pixels
    pixels = pixel_string.unpack("C*")

    update_framebuffer_from_raw_pixels(state, rectangle, framebuffer, pixels)
  end

  # @param [RubyVnc::Client::ClientState] state the current client state
  # @param [RubyVnc::Client::FramebufferUpdateRectangle] rectangle the parsed rectangle object
  # @param [Array<Integer>] framebuffer The current framebuffer of size width * height
  # @param [Array<Integer>] pixels the raw pixels
  # @return [nil] The frame buffer should be directly mutated
  def update_framebuffer_from_raw_pixels(state, rectangle, framebuffer, pixels)
    # convert the pixels to rgb format
    pixels = pixels.each_slice(4).map { |b, g, r, _| [r, g, b] }

    framebuffer.update_pixels(
      rectangle.x_position,
      rectangle.y_position,
      rectangle.width,
      rectangle.height,
      pixels
    )
  end
end
