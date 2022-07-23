require 'rspec'
require 'tcr'

RSpec.describe 'RubyVNC', type: :feature do
  let(:default_client_options) do
    {
      host: '127.0.0.1',
      port: 5902,
      logger: Logger.new(nil),
      # If TCR is running, the TCP requests will be intercepted - otherwise a real connection is opened
      socket: TCPSocket.open('127.0.0.1', 5902)
    }
  end
  let(:client_options) { default_client_options }
  let(:client) { RubyVnc::Client.new(**client_options) }

  # Creates a human readable file name for the given RSpec example/test
  #
  # @return [String] For example: when_using_authentication_it_supports_connecting_to_a_remote_VNC_server
  def test_name_for(example)
    "#{example.example_group.description} it #{example.description}".gsub(/ /, '_')
  end

  # @param [String] path The expected path to the image
  # @param [String] fallback The fallback image path which will be saved if the given path is missing
  # @return [String] The snapshot path for the given image
  def snapshot_path_for_image(path, fallback:)
    return path if File.exist?(path)

    data = File.binread(fallback)
    File.binwrite(path, data)
    path
  end

  # Takes a screenshot of the remote VNC server
  # @return [String] The path to the screenshot
  def take_screenshot(path:)
    client.negotiate
    client.authenticate_with_vnc_authentication('password123')
    client.init
    client.screenshot(path: path)

    path
  end

  # @return [Array<String>] The output_path and expected_path
  def screenshot_paths_for(example)
    output_path = File.join(FIXTURES_ROOT, 'screenshots', "#{test_name_for(example)}_actual.png")
    expected_path = File.join(FIXTURES_ROOT, 'screenshots', "#{test_name_for(example)}_expected.png")

    [output_path, expected_path]
  end

  before(:all) do
    TCR.configure do |config|
      config.hook_tcp_ports = [5902]
      config.format = 'marshal'
      config.cassette_library_dir = File.join(FIXTURES_ROOT, 'tcr')
    end
  end

  around(:each) do |example|
    cassette_name = test_name_for(example)
    TCR.use_cassette(cassette_name) do
      example.run cassette_name
    end
  end

  context 'when using authentication' do
    it 'supports taking a screenshot' do |example|
      output_path, expected_path = screenshot_paths_for(example)

      actual_screenshot = take_screenshot(path: output_path)
      expected_screenshot = snapshot_path_for_image(expected_path, fallback: output_path)
      expect(actual_screenshot).to equal_image(expected_screenshot)
    end

    context 'when using raw encoding' do
      let(:client_options) { default_client_options.merge(encodings: [RubyVnc::Client::EncodingType::RAW]) }

      it 'supports taking a screenshot' do |example|
        output_path, expected_path = screenshot_paths_for(example)

        actual_screenshot = take_screenshot(path: output_path)
        expected_screenshot = snapshot_path_for_image(expected_path, fallback: output_path)
        expect(actual_screenshot).to equal_image(expected_screenshot)
      end
    end

    context 'when using zlib encoding' do
      let(:client_options) { default_client_options.merge(encodings: [RubyVnc::Client::EncodingType::ZLIB]) }

      it 'supports taking a screenshot' do |example|
        output_path, expected_path = screenshot_paths_for(example)

        actual_screenshot = take_screenshot(path: output_path)
        expected_screenshot = snapshot_path_for_image(expected_path, fallback: output_path)
        expect(actual_screenshot).to equal_image(expected_screenshot)
      end
    end

    context 'when using tight encoding' do
      let(:client_options) { default_client_options.merge(encodings: [RubyVnc::Client::EncodingType::TIGHT]) }

      it 'supports taking a screenshot' do |example|
        output_path, expected_path = screenshot_paths_for(example)

        actual_screenshot = take_screenshot(path: output_path)
        expected_screenshot = snapshot_path_for_image(expected_path, fallback: output_path)
        expect(actual_screenshot).to equal_image(expected_screenshot)
      end
    end
  end
end
