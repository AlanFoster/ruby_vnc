# frozen_string_literal: true
require 'ruby_vnc/version'

module RubyVnc
  autoload :Client, './lib/ruby_vnc/client.rb'
  autoload :Error, './lib/ruby_vnc/error.rb'
  autoload :ProtocolVersion, './lib/ruby_vnc/protocol_version.rb'
  autoload :SynchronousReaderWriter, './lib/ruby_vnc/synchronous_reader_writer.rb'
  autoload :Crypto, './lib/ruby_vnc/crypto.rb'
end
