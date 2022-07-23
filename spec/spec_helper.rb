require 'ruby_vnc'
require 'bundler/setup'
require_relative './lib/mock_socket'
require_relative './support/matchers/equal_image'

RSPEC_ROOT = File.dirname(__FILE__)
FIXTURES_ROOT = File.join(RSPEC_ROOT, 'fixtures')

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
