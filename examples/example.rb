#!/usr/bin/env ruby

require 'bundler/setup'
require 'ruby_vnc'
require 'optparse'

options = {
  port: 5900,
  verbose: true
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

  opts.on('--verbose', 'Enable verbose logging') do |verbose|
    options[:verbose] = verbose
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
  logger: options[:verbose] ? Logger.new(STDOUT) : Logger.new(nil)
)
client.negotiate
connection = client.authenticate(
  security_type: RubyVnc::Client::SecurityType::VNC_AUTHENTICATION,
  password: options[:password]
)
puts connection
