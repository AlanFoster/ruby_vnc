# frozen_string_literal: true

# Enable legacy providers for DES support, for VNC auth
ENV['OPENSSL_CONF'] = File.expand_path(
  File.join(File.dirname(__FILE__), '..', 'config', 'openssl.conf')
)

require 'zeitwerk'
loader = Zeitwerk::Loader.for_gem
loader.setup
loader.eager_load

module RubyVnc
end
