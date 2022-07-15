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
    # In raw mode, the pixels are represented in left-to-right scan line order
    bytes_per_pixel = state.bytes_per_pixel
    framebuffer_width = state.width

    pixel_index = 0
    y_pixel_range = (rectangle.y_position...rectangle.y_position + rectangle.height)
    x_pixel_range = (rectangle.x_position...rectangle.x_position + rectangle.width)

    y_pixel_range.each do |y|
      x_pixel_range.each do |x|
        # equivalent to pixel_for(x, y) but inlined for performance
        framebuffer_index = (y * framebuffer_width) + x

        # red / green / blue
        framebuffer[framebuffer_index] =
          # red
          pixels[pixel_index + 2] << 24 |
            # green
            pixels[pixel_index + 1] << 16 |
            # blue
            pixels[pixel_index] << 8 |
            # alpha
            0xff
        pixel_index += bytes_per_pixel
      end
    end
  end
end
