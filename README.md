# RubyVnc

Prototype for consuming parts of the VNC Protocol [RFB](https://datatracker.ietf.org/doc/html/rfc6143)
Only handles authentication, and does not render anything to a screen.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ruby_vnc'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install ruby_vnc

## Usage

Create either a real VNC server, or a fake server with:

```
# Create a password configuration file
vncpasswd ./password.txt

# Kill any existing servers
vncserver -kill :1

# Create a new server
vncserver :1 -rfbport 5900 -rfbauth ./password.txt
```

Ensure it can be connected to:
```
$ vncviewer -passwd password.txt 172.16.83.2
Connected to RFB server, using protocol version 3.8
Enabling TightVNC protocol extensions
Performing standard VNC authentication
Authentication successful
Desktop name "Foo's X desktop (foo:1)"
VNC server default format:
  32 bits per pixel.
  Least significant byte first in each pixel.
  True colour: max red 255 green 255 blue 255, shift red 16 green 8 blue 0
Using default colormap which is TrueColor.  Pixel format:
  32 bits per pixel.
  Least significant byte first in each pixel.
  True colour: max red 255 green 255 blue 255, shift red 16 green 8 blue 0
Same machine: preferring raw encoding
```

Connect via the Ruby client:
```
ruby ./examples/example.rb --host 172.16.83.2
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
