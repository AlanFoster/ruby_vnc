# frozen_string_literal: true

autoload :Zlib, 'zlib'

class RubyVnc::Decoder::Tight
  module TightCompressionType
    BASIC_COMPRESSION      = 0
    JPEG_COMPRESSION       = 1
    FILL_COMPRESSION       = 2
  end

  module BasicCompressionFilterType
    # No Filter
    COPY_FILTER = 0

    PALETTE_FILTER = 1

    GRADIENT_FILTER = 2
  end

  # A primitive representing the length of the Tight pixel data.
  # There is a maximum of 3 bytes available for the length. The data is
  # a little end
  # ian stream of 7 bit bytes representing the
  # positive form of the integer. The upper bit of each byte
  # is set when there are more bytes in the stream.
  #
  # |           Value            |        Description        |
  # |----------------------------|---------------------------|
  # | 0xxxxxxx                   | for values 0..127         |
  # | 1xxxxxxx 0yyyyyyy          | for values 128..16383     |
  # | 1xxxxxxx 1yyyyyyy zzzzzzzz | for values 16384..4194303 |
  class TightPixelLength < BinData::BasePrimitive
    MAXIMUM_READS = 3

    def read_and_return_value(io)
      value = 0
      bit_shift = 0
      MAXIMUM_READS.times do
        byte = read_uint8(io)
        has_more = byte & 0x80
        seven_bit_byte = byte & 0x7f
        value |= seven_bit_byte << bit_shift
        bit_shift += 7

        break if has_more.zero?
      end

      value
    end

    def sensible_default
      0
    end

    def read_uint8(io)
      io.readbytes(1).unpack("C").at(0)
    end
  end

  # BasicCompression's CopyFilter is the pixels length followed by
  # zlib deflated raw TPIXEL data
  class TightCompressionBasicCompressionCopyFilter < BinData::Record
    endian :big

    # Stop pixels from being logged out to stop cluttering the screen
    hide :pixels

    # @!attribute [r] length
    #   @return [Integer]
    tight_pixel_length :pixels_length

    # The raw pixel update
    # @!attribute [r] pixels
    #   @return [String]
    string :pixels, read_length: -> { pixels_length }
  end

  # The Palette Filter first sends palette data, followed by
  # the image data length and image data
  class TightCompressionBasicCompressionPaletteFilter < BinData::Record
    endian :big

    # The palette begins with an unsigned byte which value is the number of colors
    # in the palette minus 1 (i.e. 1 means 2 colors, 255 means 256 colors in the palette)
    uint8 :number_of_colors_in_palette

    # In TPIXEL format
    string :palette_data, read_length: -> { (number_of_colors_in_palette + 1) * 3 }

    # @!attribute [r] length
    #   @return [Integer]
    tight_pixel_length :pixels_length

    # The raw pixel update
    # @!attribute [r] pixels
    #   @return [String]
    string :pixels, read_length: -> { pixels_length }
  end

  class TightCompressionBasicCompression < BinData::Record
    endian :big

    search_prefix :tight_compression_basic_compression

    hide :pixels

    # Two bits dedicated to which stream to use
    # 00 - Use stream 0
    # 01 - Use stream 1
    # 10 - Use stream 2
    # 11 - Use stream 3
    virtual :target_stream, value: -> { (compression_flag & 0b1100) >> 2 }

    virtual :read_filter_id, value: -> { (compression_flag & 0b0010) >> 1 }

    virtual :basic_compression_flag, value: -> { (compression_flag & 0b0001) >> 0 }

    # Used when #read_filter_id is set to 1, otherwise it should be 0
    uint8 :filter_id, onlyif: -> { (compression_flag & 0b0010) >> 1 != 0 }

    choice :filter_value, selection: -> { filter_id } do
      copy_filter BasicCompressionFilterType::COPY_FILTER
      palette_filter BasicCompressionFilterType::PALETTE_FILTER
    end
  end

  class TightCompressionJpegCompression < BinData::Record
    endian :big

    uint8 :color
  end

  class TightCompressionFillCompression < BinData::Record
    endian :big

    uint24 :fill_color
  end

  # Tight encoding
  # https://github.com/rfbproto/rfbproto/blob/de8c2c73d85f7659af7dc750c34ccdadaa8b876b/rfbproto.rst#tight-encoding
  class FramebufferUpdateRectangleTight < BinData::Record
    endian :big

    search_prefix :tight_compression

    bit4 :compression_flag

    # Informs the client which zlib compression streams should be reset before decoding the rectangle
    # Each bit is independent.
    bit1 :reset_stream3
    bit1 :reset_stream2
    bit1 :reset_stream1
    bit1 :reset_stream0

    choice :compression, selection: -> { compression_type } do
      basic_compression TightCompressionType::BASIC_COMPRESSION,
                        compression_flag: -> { compression_flag }
      jpeg_compression TightCompressionType::JPEG_COMPRESSION
      fill_compression TightCompressionType::FILL_COMPRESSION
    end

    def compression_type
      is_basic_compression = (compression_flag & 0b1000).zero?
      is_fill_compression = compression_flag == 0b1000
      is_jpeg_compression = compression_flag == 0b1001

      if is_basic_compression
        TightCompressionType::BASIC_COMPRESSION
      elsif is_fill_compression
        TightCompressionType::FILL_COMPRESSION
      elsif is_jpeg_compression
        TightCompressionType::JPEG_COMPRESSION
      else
        error_message = "unknown compression type 0b#{compression_flag.to_i.to_s(2).rjust(4, '0')}"
        raise RubyVnc::Error::RubyVncError, error_message
      end
    end
  end

  def initialize(logger: Logger.new(nil))
    @logger = logger
  end

  # @param [RubyVnc::Client::ClientState] state the current client state
  # @param [RubyVnc::Client::FramebufferUpdateRectangle] rectangle the parsed rectangle object
  # @param [Array<Integer>] framebuffer The current framebuffer of size width * height
  # @return [nil] The frame buffer should be directly mutated
  def decode(state, rectangle, framebuffer)
    framebuffer_width = state.width
    compression_type = rectangle.body.compression_type

    # Reset any of the zlib instances specified by the server
    zlib_instances[0].reset if rectangle.body.reset_stream0 == 1
    zlib_instances[1].reset if rectangle.body.reset_stream1 == 1
    zlib_instances[2].reset if rectangle.body.reset_stream2 == 1
    zlib_instances[3].reset if rectangle.body.reset_stream3 == 1

    case compression_type
    when TightCompressionType::BASIC_COMPRESSION
      filter_id = rectangle.body.compression.filter_id
      case filter_id
      when BasicCompressionFilterType::COPY_FILTER
        target_stream = rectangle.body.compression.target_stream
        pixels = rectangle.body.compression.filter_value.pixels
        pixel_string = zlib_instances[target_stream].inflate(pixels)
        pixels = pixel_string.unpack("C*")

        # In tight compression mode, the rgb pixels are represented in left-to-right scan line order
        bytes_per_pixel = 24 / 8

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
              pixels[pixel_index] << 24 |
                # green
                pixels[pixel_index + 1] << 16 |
                # blue
                pixels[pixel_index + 2] << 8 |
                # alpha
                0xff
            pixel_index += bytes_per_pixel
          end
        end
      when BasicCompressionFilterType::PALETTE_FILTER
          logger.info("unhandled filter type palette")
      else
        logger.info("Unhandled filter type #{filter_id}")
      end

      # Apply a single color to a full rectangle
    when TightCompressionType::FILL_COMPRESSION
      fill_color = rectangle.body.compression.fill_color
      new_pixel =
        fill_color << 8 |
          # alpha
          0xff

      framebuffer_width = server_init.framebuffer_width

      y_pixel_range = (rectangle.y_position...rectangle.y_position + rectangle.height)
      x_pixel_range = (rectangle.x_position...rectangle.x_position + rectangle.width)
      y_pixel_range.each do |y|
        x_pixel_range.each do |x|
          # equivalent to pixel_for(x, y) but inlined for performance
          framebuffer_index = (y * framebuffer_width) + x
          framebuffer[framebuffer_index] = new_pixel
        end
      end
    else
      logger.error("Unsupported compression type #{compression_type}")
    end
  end

  protected

  # The logger
  # @!attribute [r] logger
  #   @return [Logger]
  attr_reader :logger

  # Instances of Zlib::Inflate required for Tight inflation
  # @return [Array<Zlib::Inflate>]
  def zlib_instances
    @zlib_instances ||= [
      ::Zlib::Inflate.new,
      ::Zlib::Inflate.new,
      ::Zlib::Inflate.new,
      ::Zlib::Inflate.new
    ]
  end
end
