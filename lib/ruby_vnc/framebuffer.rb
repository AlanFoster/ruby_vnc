# frozen_string_literal: true

require 'rmagick'

# The framebuffer object which stores the RGB values of the remote server
class RubyVnc::Framebuffer
  def initialize(width, height, pixels = nil)
    @width = width
    @height = height
    @image = Magick::Image.new(@width, @height) do |info|
      info.depth = 8
    end
  end

  # @param [Integer] x
  # @param [Integer] y
  # @param [Integer] width
  # @param [Integer] height
  # @param [Array<Array<Integer>>] pixels An array of array of pixels in 8-bit RGB format for example [[255, 0, 255]]
  def update_pixels(x, y, width, height, pixels)
    unless pixels.any?
      $stderr.puts "pixels are empty for some reason"
      puts caller
    end

    pixels = pixels.map { |r, g, b| Magick::Pixel.new(r * 255, g * 255, b * 255, 255) }
    @image.store_pixels(x, y, width, height, pixels)
  end

  def save(path)
    @image.write(path)
  end
end
