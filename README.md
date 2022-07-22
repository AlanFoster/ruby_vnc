# RubyVnc

Prototype for consuming parts of the VNC Protocol.

- [Official RFB Specification](https://datatracker.ietf.org/doc/html/rfc6143)
- [Improved community maintained RFB specification](https://github.com/rfbproto/rfbproto)

Handles negotiation, authentication (None and VNC), setting frame pixel format, requesting screen buffer updates,
saving a screenshot to file, and GUI support.

Supported encodings:
- Raw
- Zlib
- Tight

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ruby_vnc'
```

And then execute:

```
bundle install
```

Or install it yourself as:
```
gem install ruby_vnc
```

## Examples

Connect to the VNC Server:

```
bundle exec ruby ./examples/example.rb --host 172.16.83.2
```

Specify a custom port, password, and encoding:

```
bundle exec ruby ./examples/example.rb --host 127.0.0.1 --port 5902 --password password123 --encodings tight
```

Take a screenshot:

```
bundle exec ruby ./examples/example.rb --host 127.0.0.1 --port 5902 --password password123 --screenshot ./tmp/result.png
```

Open a interactive GUI:

```
bundle exec ruby ./examples/example.rb --host 127.0.0.1 --port 5902 --password password123 --gui
```

Specify log level, logging all messages:

```
bundle exec ruby ./examples/example.rb --host  172.16.83.2 --port 5902 --password password123 --gui --log-level 0
```

## Targets

Either create a real VNC server and connect to it. Or create a local VNC server with docker:

```
docker-compose up
```

Or create a fake server with:

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

## Development

Install dependencies:

```
bundle install
```

Run tests:

```
bundle exec rspec
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
