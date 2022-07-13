require 'rspec'

RSpec.describe RubyVnc::Client::TightPixelLength do
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
        expected = 30439
        expect(described_class.read(input)).to eq(expected)
      end
    end
  end
end
