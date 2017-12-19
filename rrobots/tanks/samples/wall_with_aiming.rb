require 'rrobots'
require "#{File.dirname(__FILE__)}/utils/sample"

class WallWithAiming
  include Robot
  include SampleUtil

  def tick events
    wall_move true
    shoot_uniform_speed
  end
end
