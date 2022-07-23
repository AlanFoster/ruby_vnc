# frozen_string_literal: true

autoload :Zlib, 'zlib'

class RubyVnc::Decoder::Tight
  # If the byte size is less than this value after the filter has been applied, then
  # No compression is used, and instead the raw data is sent
  MAXIMUM_BYTES_BEFORE_COMPRESSION = 12

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

  # The palette size is an unsigned byte. The value is the number of colors
  # in the palette minus 1 (i.e. 1 means 2 colors, 255 means 256 colors in the palette)
  #
  # For improved readability when debugging, this BinData primitive reads the value and increments it
  # by one before setting it on the BinData record
  class TightCompressionBasicCompressionPaletteSize < BinData::BasePrimitive
    def read_and_return_value(io)
      read_uint8(io) + 1
    end

    def sensible_default
      0
    end

    def read_uint8(io)
      io.readbytes(1).unpack1('C')
    end
  end

  # A primitive representing the length of the Tight pixel data.
  # There is a maximum of 3 bytes available for the length. The data is
  # a little endian stream of 7 bit bytes representing the
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
      io.readbytes(1).unpack1('C')
    end
  end

  # BasicCompression's CopyFilter is the pixels length followed by
  # zlib deflated raw TPIXEL data
  class TightCompressionBasicCompressionCopyFilter < BinData::Record
    endian :big

    # @!attribute [r] length
    #   @return [Integer]
    tight_pixel_length :pixels_length,
                       onlyif: -> { uncompressed_size >= MAXIMUM_BYTES_BEFORE_COMPRESSION }

    # The raw pixel update
    # @!attribute [r] pixels
    #   @return [String]
    string :pixels, read_length: -> { uncompressed_size < MAXIMUM_BYTES_BEFORE_COMPRESSION ? uncompressed_size : pixels_length }

    def uncompressed_size
      bits_per_pixel = 24
      (eval_parameter(:width) * bits_per_pixel + 7) / 8 * eval_parameter(:height)
    end
  end

  # The Palette Filter first sends palette data, followed by
  # the image data length and image data
  class TightCompressionBasicCompressionPaletteFilter < BinData::Record
    endian :big

    search_prefix :tight_compression_basic_compression

    # the number of colors available in the palette
    palette_size :number_of_colors_in_palette

    # In TPIXEL format, i.e. RGB
    string :palette_data, read_length: -> { number_of_colors_in_palette * 3 }

    # @!attribute [r] length
    #   @return [Integer]
    tight_pixel_length :pixels_length,
                       onlyif: -> { uncompressed_size >= MAXIMUM_BYTES_BEFORE_COMPRESSION }

    # The raw pixel update
    # @!attribute [r] pixels
    #   @return [String]
    string :pixels, read_length: -> { uncompressed_size < MAXIMUM_BYTES_BEFORE_COMPRESSION ? uncompressed_size : pixels_length }

    def uncompressed_size
      # If the palette size is 2, then each pixel is encoded in 1 bit
      bits_per_pixel = number_of_colors_in_palette <= 2 ? 1 : 8

      (eval_parameter(:width) * bits_per_pixel + 7) / 8 * eval_parameter(:height)
    end
  end

  class TightCompressionBasicCompression < BinData::Record
    endian :big

    search_prefix :tight_compression_basic_compression

    # Two bits dedicated to which stream to use
    #
    # 00 - Use stream 0
    # 01 - Use stream 1
    # 10 - Use stream 2
    # 11 - Use stream 3
    virtual :target_stream, value: -> { (compression_flag & 0b0011) }
    virtual :read_filter_id, value: -> { (compression_flag & 0b0100) >> 2 }

    # Used when #read_filter_id is set to 1, otherwise it should be 0
    uint8 :filter_id, onlyif: -> { (compression_flag & 0b0100) >> 2 == 1 }

    choice :filter_value, selection: -> { filter_id } do
      copy_filter BasicCompressionFilterType::COPY_FILTER,
                  width: -> { width },
                  height: -> { height }
      palette_filter BasicCompressionFilterType::PALETTE_FILTER,
                     width: -> { width },
                     height: -> { height }
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
  def decode(_state, rectangle, framebuffer)
    compression_type = rectangle.body.compression_type

    # Reset any of the zlib instances specified by the server
    zlib_instances[0].reset if rectangle.body.reset_stream0 == 1
    zlib_instances[1].reset if rectangle.body.reset_stream1 == 1
    zlib_instances[2].reset if rectangle.body.reset_stream2 == 1
    zlib_instances[3].reset if rectangle.body.reset_stream3 == 1

    case compression_type
    when TightCompressionType::BASIC_COMPRESSION
      filter_id = rectangle.body.compression.filter_id
      filter = rectangle.body.compression.filter_value

      if filter.uncompressed_size >= MAXIMUM_BYTES_BEFORE_COMPRESSION
        target_stream = rectangle.body.compression.target_stream
        pixel_string = zlib_instances[target_stream].inflate(filter.pixels)
      else
        pixel_string = filter.pixels
      end

      case filter_id
      when BasicCompressionFilterType::COPY_FILTER
        # convert 8 bit RGB pixels to RGB format
        pixels = pixel_string.unpack('C*').each_slice(3)

        framebuffer.update_pixels(
          rectangle.x_position,
          rectangle.y_position,
          rectangle.width,
          rectangle.height,
          pixels
        )
      when BasicCompressionFilterType::PALETTE_FILTER
        palette = filter.palette_data.unpack("C*").each_slice(3).to_a

        # If the number of colors is 2, then each pixel is encoded in 1 bit,
        if filter.number_of_colors_in_palette <= 2
          pixels = pixel_string.unpack1('b*').chars.map { |palette_index| palette[palette_index.to_i] }
        else
          # If there are more than 2 colors, each pixel is encoded in 8 bits as a lookup of the palette
          pixels = pixel_string.unpack('C*').map { |palette_index| palette[palette_index] }
        end

        framebuffer.update_pixels(
          rectangle.x_position,
          rectangle.y_position,
          rectangle.width,
          rectangle.height,
          pixels
        )
      else
        logger.error("Unhandled filter type #{filter_id}")
      end

    # Apply a single color to a full rectangle
    when TightCompressionType::FILL_COMPRESSION
      fill_color = rectangle.body.compression.fill_color
      # convert 8 bit RGB pixels to RGB format
      rgb = [
        (fill_color >> 16 & 0xff),
        (fill_color >> 8 & 0xff),
        (fill_color >> 0 & 0xff)
      ]
      pixels = (rectangle.width * rectangle.height).times.map { rgb }

      framebuffer.update_pixels(
        rectangle.x_position,
        rectangle.y_position,
        rectangle.width,
        rectangle.height,
        pixels
      )
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
