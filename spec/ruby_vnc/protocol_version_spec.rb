require 'rspec'

RSpec.describe RubyVnc::ProtocolVersion do
  describe '#from_version_string' do
    context 'when the input is valid' do
      subject { described_class.from_version_string("RFB 003.008\n") }

      it 'parses the major version' do
        expect(subject.major).to eq(3)
      end

      it 'parses the minor version' do
        expect(subject.minor).to eq(8)
      end
    end

    context 'when the input is invalid' do
      subject { described_class.from_version_string("example string") }

      it 'parses the major version' do
        expect(subject.major).to eq(0)
      end

      it 'parses the minor version' do
        expect(subject.minor).to eq(0)
      end
    end
  end

  describe '#to_version_string' do
    subject { described_class.new(3, 8) }

    it 'returns a valid version string' do
      expect(subject.to_version_string).to eq 'RFB 003.008'
    end
  end
end
