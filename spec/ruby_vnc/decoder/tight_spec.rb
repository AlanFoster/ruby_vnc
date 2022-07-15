# frozen_string_literal: true

require 'rspec'

RSpec.describe RubyVnc::Decoder::Tight do
  describe '#new' do
    it 'can be instantiated' do
      expect(described_class.new).to be_instance_of(described_class)
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
