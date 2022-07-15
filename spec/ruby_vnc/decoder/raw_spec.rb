require 'rspec'

RSpec.describe RubyVnc::Decoder::Raw do
  describe '#new' do
    it 'can be instantiated' do
      expect(described_class.new).to be_instance_of(described_class)
    end
  end
end
