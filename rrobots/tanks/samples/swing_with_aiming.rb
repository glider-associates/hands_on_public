require 'rrobots'
require "#{File.dirname(__FILE__)}/utils/sample"

require 'securerandom'

class SwingWithAiming
  include Robot
  include SampleUtil

  def tick events
    @turn_angle = 0
    if time % 320 < 30
      @turn_angle = 10 * SecureRandom.random_number
      turn @turn_angle
    end
    if (time % 80) < 40
      accelerate_with_random 1, true
    else
      accelerate_with_random -1, true
    end
    shoot_uniform_speed
  end
end
