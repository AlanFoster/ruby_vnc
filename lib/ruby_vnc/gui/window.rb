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
      window.close if event[:type] == :down && event[:key] == 'escape'
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
end
