require 'rrobots'
require "#{File.dirname(__FILE__)}/utils/sample"

class Aiming
  include Robot
  include SampleUtil

  def tick events
    @turn_angle = 0
    shoot_uniform_speed
  end
end
