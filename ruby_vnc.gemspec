require_relative 'lib/ruby_vnc/version'

Gem::Specification.new do |spec|
  spec.name          = "ruby_vnc"
  spec.version       = RubyVnc::VERSION
  spec.authors       = [""]
  spec.email         = [""]

  spec.summary       = %q{ruby_vnc}
  spec.description   = %q{ruby_vnc}
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'bindata'
  spec.add_runtime_dependency 'chunky_png'
  spec.add_runtime_dependency 'zeitwerk'
end
