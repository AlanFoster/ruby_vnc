require 'rspec'

RSpec.describe RubyVnc::Crypto do
  describe '#des' do
    it 'generates the response for the given challenge and password' do
      challenge = "\xcc\x4c\x29\xe5\x09\x4f\x89\xe5\xf2\x1b\x08\x78\x6d\x23\xa2\xcd".b
      password = 'COW'
      expected = "\x28\x3a\x2e\xf4\xb8\xfe\xf2\x21\xe6\xc7\x2b\x4c\x26\x33\x1e\x96".b
      expect(subject.des(challenge, password)).to eq expected
    end
  end
end
