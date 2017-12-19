require 'rrobots'
require "#{File.dirname(__FILE__)}/utils/sample"

class CircleShooter
  include Robot
  include SampleUtil

  def tick events
    accelerate 1
    turn 2
    quick_shoot
  end
end
