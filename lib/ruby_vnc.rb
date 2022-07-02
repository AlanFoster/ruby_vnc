# frozen_string_literal: true
require 'ruby_vnc/version'

module RubyVnc
  autoload :Client, './lib/ruby_vnc/client.rb'
  autoload :Error, './lib/ruby_vnc/error.rb'
  autoload :ProtocolVersion, './lib/ruby_vnc/protocol_version.rb'
end
