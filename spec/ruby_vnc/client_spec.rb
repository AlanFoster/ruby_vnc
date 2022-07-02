require 'rspec'

RSpec.describe RubyVnc::Client do
  subject { described_class.new(socket: socket) }

  describe '#negotiate' do
    context 'when the server protocol version is not supported' do
      let(:socket) { MockSocket.new("RFB 004.003\n") }

      it 'raises an error' do
        expect { subject.negotiate }.to raise_error RubyVnc::Error::UnsupportedVersionError, /Unsupported server protocol version/
      end
    end

    context 'when the version is supported' do
      context 'when there is a security handshake failure' do
        let(:socket) do
          data = (
            "\x52\x46\x42\x20\x30\x30\x33\x2e\x30\x30\x38\x0a\x00\x00\x00\x00" \
            "\x00\x00\x00\x1a\x54\x6f\x6f\x20\x6d\x61\x6e\x79\x20\x73\x65\x63" \
            "\x75\x72\x69\x74\x79\x20\x66\x61\x69\x6c\x75\x72\x65\x73"
          ).b

          MockSocket.new(data)
        end

        it 'raises an error' do
          (expect { subject.negotiate }).to raise_error(RubyVnc::Error::SecurityHandshakeFailure, /Security handshake failed/) do |error|
            expect(error.failure_reason.reason_string).to eq 'Too many security failures'
          end
        end
      end

      context 'when the security handshake succeeds with VNC SecurityType' do
        let(:socket) do
          data = (
            # Server protocol version
            "\x52\x46\x42\x20\x30\x30\x33\x2e\x30\x30\x38\x0a" +
            # Security types
            "\x02\x02\x10"
          ).b

          MockSocket.new(data)
        end

        it 'returns the security types' do
          expect(subject.negotiate).to eq([RubyVnc::Client::SecurityType::VNC_AUTHENTICATION, RubyVnc::Client::SecurityType::TIGHT])
        end
      end
    end
  end
end
