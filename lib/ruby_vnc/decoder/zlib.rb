# frozen_string_literal: true

autoload :Zlib, 'zlib'

# The Zlib decoder which implements decoding https://github.com/rfbproto/rfbproto/blob/de8c2c73d85f7659af7dc750c34ccdadaa8b876b/rfbproto.rst#zlib-encoding
class RubyVnc::Decoder::Zlib < RubyVnc::Decoder::Raw
  # @param [object] state the state
  # @param [object] rectangle the rectangle
  # @param [Array<Integer>] The current framebuffer of size width * height
  # @return [nil] The frame buffer should be directly mutated
  def decode(state, rectangle, framebuffer)
    pixel_string = zlib.inflate(rectangle.body.pixels)
    pixels = pixel_string.unpack("C*")

    # After inflating the pixel data, update the framebuffer with the availiable raw pixels
    update_framebuffer_from_raw_pixels(state, rectangle, framebuffer, pixels)
  end

  # A shared instance of Zlib::Inflate
  # https://github.com/rfbproto/rfbproto/blob/de8c2c73d85f7659af7dc750c34ccdadaa8b876b/rfbproto.rst#766zlib-encoding
  # @return [Zlib::Inflate]
  def zlib
    @zlib ||= ::Zlib::Inflate.new
  end
end
