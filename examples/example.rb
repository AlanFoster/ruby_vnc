#!/usr/bin/env ruby

require 'bundler/setup'
require 'ruby_vnc'
require 'optparse'

options = {
  port: 5900,
  verbose: true,
  password: nil,
  encodings: RubyVnc::Client::DEFAULT_ENCODINGS,
  screenshot_path: nil
}
options_parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename(__FILE__)} [options]"

  opts.on('-h', '--help', 'Help banner') do
    return print(opts.help)
  end

  opts.on('--host=HOST', 'The target host') do |host|
    options[:host] = host
  end

  opts.on('--port=PORT', 'The target port') do |port|
    options[:port] = port
  end

  opts.on('--password=PASSWORD', 'The target host') do |password|
    options[:password] = password
  end

  opts.on('--verbose', 'Enable verbose logging') do |verbose|
    options[:verbose] = verbose
  end

  opts.on('--encodings x,y,z', Array, 'User defined encodings') do |encoding_names|
    options[:encodings] = encoding_names.map do |name|
      name = name.upcase
      unless RubyVnc::Client::EncodingType.const_defined?(name)
        raise "Unexpected encoding name #{name}, expected one of #{RubyVnc::Client::EncodingType.constants.join(', ')}"
      end

      RubyVnc::Client::EncodingType.const_get(name)
    end
  end

  opts.on('--screenshot path', 'Screenshot target path') do |screenshot_path|
    options[:screenshot_path] = screenshot_path
  end
end
options_parser.parse!

if options[:host].nil?
  puts 'Host required'
  puts options_parser.help
  exit 1
end

client = RubyVnc::Client.new(
  host: options[:host],
  port: options[:port],
  logger: options[:verbose] ? Logger.new($stdout) : Logger.new(nil),
  encodings: options[:encodings]
)
client.negotiate
authenticated = client.authenticate(
  security_type: RubyVnc::Client::SecurityType::VNC_AUTHENTICATION,
  password: options[:password]
)
unless authenticated
  puts 'Failed authentication'
  exit 1
end

client.init
client.request_framebuffer_update
client.screenshot(path: options[:screenshot_path]) if options[:screenshot_path]
