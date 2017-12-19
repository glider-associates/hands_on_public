require 'rrobots'
require "#{File.dirname(__FILE__)}/utils/sample"

require 'securerandom'

class CircleWithAiming
  include Robot
  include SampleUtil

  def tick events
    @turn_angle ||= 3
    if time % 80 == 0
      @turn_angle *= (SecureRandom.random_number * 0.3 + 0.85)
    end
    turn @turn_angle
    accelerate_with_random 1, true
    shoot_uniform_speed
  end
end
