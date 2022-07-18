# frozen_string_literal: true

# Workaround to stop the global namespace being polluted by Ruby2D
# Should be fixed in newer releases:
# https://github.com/ruby2d/ruby2d/issues/173
class << self
  alias :old_include :include

  def include(mod)
    return if caller&.first&.include?('lib/ruby2d.rb')

    old_include mod
  end
end

def self.extend(mod)
  return if caller&.first&.include?('lib/ruby2d.rb')

  super(mod)
end

autoload :Ruby2D, 'ruby2d'

class RubyVnc::Gui::Window
  # @param [RubyVnc::Client] client
  def initialize(client:, logger: Logger.new(nil))
    @client = client
    @logger = logger
    default_options = {
      title: 'VNC Client',
      fps_cap: 24,
      width: client.state.width,
      height: client.state.height,
      # viewport_width: 800,
      # viewport_height: 600,
      diagnostics: false,
      resizable: true
    }
    @filesystem_framebuffer_path = './tmp/framebuffer.png'
    @window = Ruby2D::Window.new
    default_options.each do |option_name, value|
      @window.set(option_name => value)
    end
  end

  def run
    keyboard_state = {
      has_shift_down: false
    }
    pointer_state = {
      left: false,
      middle: false,
      right: false
    }
    fps = ::Ruby2D::Text.new 'fps'
    previous_image = nil
    update_requested = false
    last_update_request = nil

    window.on :key_down do |event|
      window.close if event.key == 'escape'

      keyboard_state[:has_shift_down] = true if event.key == 'left shift' || event.key == 'right shift'

      key_value = vnc_key_for(keyboard_state, event.key)
      unless key_value
        logger.info("Unknown key #{event.key}")
        next
      end

      client.key_down(key_value)
      update_requested = true
    end

    window.on :key_held do |event|
      key_value = vnc_key_for(keyboard_state, event.key)
      next unless key_value

      client.key_down(key_value)
      update_requested = true
    end

    window.on :key_up do |event|
      keyboard_state[:has_shift_down] = false if event.key == 'left shift' || event.key == 'right shift'

      key_value = vnc_key_for(keyboard_state, event.key)
      next unless key_value

      client.key_up(key_value)
      update_requested = true
    end

    window.on :mouse_down do |event|
      pointer_state[event.button] = true
      client.click_pointer(event.x, event.y, pointer_state)
      update_requested = true
    end

    window.on :mouse_up do |event|
      pointer_state[event.button] = false
      client.click_pointer(event.x, event.y)
      update_requested = true
    end

    window.on :mouse_move do |event|
      client.move_pointer(event.x, event.y, pointer_state)
      update_requested = true
    end

    window.update do
      fps.text = window.get(:fps)
      fps.z = 2

      requires_framebuffer_update_request = (
        # Are we the first request?
        last_update_request.nil? ||
          # Has a certain amount of time passed since the last request?
          (Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond) - last_update_request > 1000) ||
          # Has an update been requested by an event handler? Event handler requests can still be throttled, i.e. for mouse moves
          (update_requested && (Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond) - last_update_request) > 500)
      )

      if requires_framebuffer_update_request
        require_full_screen_render = last_update_request.nil?
        client.request_framebuffer_update(incremental: !require_full_screen_render)
        last_update_request = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)

        update_requested = false
      end
      has_updated = false
      5.times { has_updated |= client.poll_framebuffer_update }

      # Write the framebuffer to disk for now as Ruby2D doesn't expose setting a raw buffer
      if has_updated
        logger.info('Saving to disk to update GUI')
        client.state.framebuffer.save(@filesystem_framebuffer_path)
        window.remove(previous_image) if previous_image

        image = ::Ruby2D::Image.new(@filesystem_framebuffer_path)
        image.z = 1
        window.add(image)
        previous_image = image
      end
    end

    window.add(fps)
    window.show
  end

  protected

  # @!attribute [r] window
  #   @return [Ruby2D::Window]
  attr_reader :window

  # @!attribute [r] client
  #   @return [RubyVnc::Client]
  attr_reader :client

  # The logger
  # @!attribute [r] logger
  #   @return [Logger]
  attr_reader :logger

  # @param [string] ruby2d_key Ruby2D's key value
  # @return [Integer, nil] The matching vnc scan code
  def vnc_key_for(keyboard_state, ruby2d_key)

    logger.info("key: #{ruby2d_key}")

    # Mapping of Ruby2D's keys to RubyVnc's keys
    key_mapping = {
      'backspace' => RubyVnc::Client::KeyboardKey::BACKSPACE,
      'tab' => RubyVnc::Client::KeyboardKey::TAB,
      'return' => RubyVnc::Client::KeyboardKey::RETURN,
      'escape' => RubyVnc::Client::KeyboardKey::ESCAPE,
      'insert' => RubyVnc::Client::KeyboardKey::INSERT,
      'delete' => RubyVnc::Client::KeyboardKey::DELETE,
      'home' => RubyVnc::Client::KeyboardKey::HOME,
      'end' => RubyVnc::Client::KeyboardKey::END_KEY,
      'pageup' => RubyVnc::Client::KeyboardKey::PAGE_UP,
      'pagedown' => RubyVnc::Client::KeyboardKey::PAGE_DOWN,
      'left' => RubyVnc::Client::KeyboardKey::LEFT,
      'up' => RubyVnc::Client::KeyboardKey::UP,
      'right' => RubyVnc::Client::KeyboardKey::RIGHT,
      'down' => RubyVnc::Client::KeyboardKey::DOWN,
      'f1' => RubyVnc::Client::KeyboardKey::F1,
      'f2' => RubyVnc::Client::KeyboardKey::F2,
      'f3' => RubyVnc::Client::KeyboardKey::F3,
      'f4' => RubyVnc::Client::KeyboardKey::F4,
      'f5' => RubyVnc::Client::KeyboardKey::F5,
      'f6' => RubyVnc::Client::KeyboardKey::F6,
      'f7' => RubyVnc::Client::KeyboardKey::F7,
      'f8' => RubyVnc::Client::KeyboardKey::F8,
      'f9' => RubyVnc::Client::KeyboardKey::F9,
      'f10' => RubyVnc::Client::KeyboardKey::F10,
      'f11' => RubyVnc::Client::KeyboardKey::F11,
      'f12' => RubyVnc::Client::KeyboardKey::F12,
      'left shift' => RubyVnc::Client::KeyboardKey::SHIFT_LEFT,
      'right shift' => RubyVnc::Client::KeyboardKey::SHIFT_RIGHT,
      'left ctrl' => RubyVnc::Client::KeyboardKey::CONTROL_LEFT,
      'right ctrl' => RubyVnc::Client::KeyboardKey::CONTROL_RIGHT,
      'left gui' => RubyVnc::Client::KeyboardKey::META_LEFT,
      'right gui' => RubyVnc::Client::KeyboardKey::META_RIGHT,
      'left alt' => RubyVnc::Client::KeyboardKey::ALT_LEFT,
      'right alt' => RubyVnc::Client::KeyboardKey::ALT_RIGHT,

      'space' => ' '.ord
    }

    # Lookups for when the shift key is pressed
    shift_mappings = {
      '1' => '!',
      '2' => '@',
      '3' => '£',
      '4' => '$',
      '5' => '%',
      '6' => 'x',
      '7' => 'x',
      '8' => 'x',
      '9' => 'x',
      '0' => 'x',
      '-' => '_',
      '=' => '+'
    }

    # Perform an initial lookup of the string key to RubyVnc keys
    result = key_mapping[ruby2d_key]
    return result if result

    # Check a-z,A-Z,0-9
    if ruby2d_key.match(/\A[a-zA-Z0-9]\Z/)
      new_key = keyboard_state[:has_shift_down] ? shift_mappings.fetch(ruby2d_key, ruby2d_key) : ruby2d_key
      $stderr.puts "new key: #{new_key} keyboard state #{keyboard_state}"
      return new_key.ord
    end

    nil
  end
end
