# frozen_string_literal: true

autoload :Magick, 'rmagick'

RSpec::Matchers.define :equal_image do |expected_path|
  match do |actual_path|
    expected_pixels = pixels_for(expected_path)
    actual_pixels = pixels_for(actual_path)

    expect(expected_pixels == actual_pixels).to be true
  end

  # @param [String] path The file path to the image
  def pixels_for(path)
    image = Magick::Image.read(path).first
    image.export_pixels_to_str(0, 0, image.columns, image.rows)
  end
end
