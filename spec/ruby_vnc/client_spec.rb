require 'rspec'

RSpec.describe RubyVnc::Client do
  subject { described_class.new(socket: socket) }

  describe '#negotiate' do
    context 'when the server protocol version is not supported' do
      let(:socket) { RubyVnc::SynchronousReaderWriter.new(MockSocket.new("RFB 004.003\n")) }

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

          RubyVnc::SynchronousReaderWriter.new(MockSocket.new(data))
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

          RubyVnc::SynchronousReaderWriter.new(MockSocket.new(data))
        end

        it 'returns the security types' do
          expect(subject.negotiate).to eq([RubyVnc::Client::SecurityType::VNC_AUTHENTICATION, RubyVnc::Client::SecurityType::TIGHT])
        end
      end
    end
  end

  describe '#authenticate' do
    context 'when authenticating with an unsupported authentication method' do
      let(:socket) do
        data = ''.b
        RubyVnc::SynchronousReaderWriter.new(MockSocket.new(data))
      end

      before(:each) do
        handshake = RubyVnc::Client::SecurityHandshake.new(
          number_of_security_types: 1,
          security_types: [RubyVnc::Client::SecurityType::NONE]
        )
        allow(subject).to receive(:handshake).and_return(handshake)
      end

      it 'authenticates successfully when the password is smaller than 8 bytes' do
        expect { subject.authenticate(security_type: RubyVnc::Client::SecurityType::TIGHT) }.to raise_error ::RubyVnc::Error::RubyVncError, 'security type not supported by server'
      end
    end

    context 'when authenticating with VNC_AUTHENTICATION' do
      let(:socket) do
        data = (
          # Security challenge
          "\xa5\xec\x33\x6f\x4f\xa2\x5b\x75\x74\x56\xdb\x54\x97\x68\xfe\x7e" +
          # Authentication success result
          "\x00\x00\x00\x00"
        ).b

        RubyVnc::SynchronousReaderWriter.new(MockSocket.new(data))
      end

      before(:each) do
        handshake = RubyVnc::Client::SecurityHandshake.new(
          number_of_security_types: 1,
          security_types: [RubyVnc::Client::SecurityType::VNC_AUTHENTICATION]
        )
        allow(subject).to receive(:handshake).and_return(handshake)
      end

      it 'authenticates successfully when the password is smaller than 8 bytes' do
        result = subject.authenticate(password: 'password123', security_type: RubyVnc::Client::SecurityType::VNC_AUTHENTICATION)
        expect(result).to eq true
      end
    end
  end
end
