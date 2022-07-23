# frozen_string_literal: true

require 'rspec'

RSpec.describe RubyVnc::Decoder::Tight do
  describe '#new' do
    it 'can be instantiated' do
      expect(described_class.new).to be_instance_of(described_class)
    end
  end

  describe described_class::FramebufferUpdateRectangleTight do
    context 'when basic encoding is used without a filter type' do
      context 'and a length field is not present' do
        it 'decodes correctly' do
          data = (
            # Compression stream information and encoding type
            "\x00" +
              # no length field is present
              # image data
              "\x00\x00\x00\xff\xff\xff"
          ).b

          expected = {
            compression_flag: 0,
            reset_stream3: 0,
            reset_stream2: 0,
            reset_stream1: 0,
            reset_stream0: 0,
            compression: {
              target_stream: 0,
              read_filter_id: 0,
              filter_value: {
                pixels: "\x00\x00\x00\xFF\xFF\xFF".b
              }
            }
          }

          expect(described_class.read(data, width: 2, height: 1)).to eq(expected)
        end
      end

      context 'and a length field is present' do
        it 'decodes correctly' do
          data = (
            # Compression stream information and encoding type
            "\x00" +
              # length
              "\x0a" +
              # compressed image data
              "\xc2\x23\x05\xd7\x0e\x00\x00\x00\xff\xff"
          ).b

          expected = {
            compression_flag: 0,
            reset_stream3: 0,
            reset_stream2: 0,
            reset_stream1: 0,
            reset_stream0: 0,
            compression: {
              target_stream: 0,
              read_filter_id: 0,
              filter_value: {
                pixels_length: 10,
                pixels: "\xc2\x23\x05\xd7\x0e\x00\x00\x00\xff\xff".b
              }
            }
          }

          expect(described_class.read(data, width: 2, height: 6)).to eq(expected)
        end
      end
    end

    context 'when basic encoding is used with palette filter' do
      context 'and a length field is not present' do
        it 'decodes correctly' do
          data = (
            # Compression stream information and encoding type
            "\x50" +
              # filter id - palette
              "\x01" +
              # number of colors in palette
              "\x01" +
              # palette data
              "\x1b\x6a\xcb\xce\xce\xce" +
              # no length present
              # uncompressed image data
              "\x03\x80\x03\x80\x03\x80\x03\x80\x03\x80"
          ).b

          expected = {
            compression_flag: 5,
            reset_stream3: 0,
            reset_stream2: 0,
            reset_stream1: 0,
            reset_stream0: 0,
            compression: {
              target_stream: 1,
              read_filter_id: 1,
              filter_id: 1,
              filter_value: {
                number_of_colors_in_palette: 1,
                palette_data: "\x1b\x6a\xcb\xce\xce\xce".b,
                pixels: "\x03\x80\x03\x80\x03\x80\x03\x80\x03\x80".b
              }
            }
          }
          expect(described_class.read(data, width: 9, height: 5)).to eq(expected)
        end
      end

      context 'and a length field is present with 3 palette values' do
        it 'decodes correctly' do
          data = (
            # Compression stream information and encoding type
            "\x60" +
              # filter id - palette
              "\x01" +
              # number of colors in palette
              "\x02" +
              # palette data
              "\x0c\x0c\x0c\xcc\xb1\x76\x34\x0d\x0d" +
              # length
              "\x0e" +
              # compressed image data
              "\x42\xdf\xef\x0e\x2e\xb6\x49\x00\x00\x00\x00\x00\xff\xff"
          ).b

          expected = {
            compression_flag: 6,
            reset_stream3: 0,
            reset_stream2: 0,
            reset_stream1: 0,
            reset_stream0: 0,
            compression: {
              target_stream: 2,
              read_filter_id: 1,
              filter_id: 1,
              filter_value: {
                number_of_colors_in_palette: 2,
                palette_data: "\x0c\x0c\x0c\xcc\xb1\x76\x34\x0d\x0d".b,
                pixels_length: 14,
                pixels: "\x42\xdf\xef\x0e\x2e\xb6\x49\x00\x00\x00\x00\x00\xff\xff".b
              }
            }
          }
          expect(described_class.read(data, width: 9, height: 5)).to eq(expected)
        end
      end

      context 'and a length field is present' do
        it 'decodes correctly' do
          data = (
            # Compression stream information and encoding type
            "\x50" +
              # filter id - palette
              "\x01" +
              # number of colors in palette
              "\x01" +
              # palette data
              "\x00\x00\x00\xff\xff\xff" +
              # length
              "\x08" +
              # compressed image data
              "\xc2\x00\x00\x00\x00\x00\xff\xff"
          ).b

          expected = {
            compression_flag: 5,
            reset_stream3: 0,
            reset_stream2: 0,
            reset_stream1: 0,
            reset_stream0: 0,
            compression: {
              target_stream: 1,
              read_filter_id: 1,
              filter_id: 1,
              filter_value: {
                number_of_colors_in_palette: 1,
                palette_data: "\x00\x00\x00\xFF\xFF\xFF".b,
                pixels_length: 8,
                pixels: "\xC2\x00\x00\x00\x00\x00\xFF\xFF".b
              }
            }
          }
          expect(described_class.read(data, width: 2, height: 17)).to eq(expected)
        end
      end
    end
  end

  describe described_class::TightPixelLength do
    describe '#read' do
      context 'when 0..127' do
        it 'reads the correct value' do
          input = "\x0F"
          expected = 15
          expect(described_class.read(input)).to eq(expected)
        end
      end

      context 'when 128..16383' do
        it 'reads the correct value' do
          input = "\xe7\x3d"
          expected = 7911
          expect(described_class.read(input)).to eq(expected)
        end
      end

      context 'when 16384..4194303' do
        it 'reads the correct value' do
          input = "\xe7\xed\x01"
          expected = 30_439
          expect(described_class.read(input)).to eq(expected)
        end
      end
    end
  end
end
