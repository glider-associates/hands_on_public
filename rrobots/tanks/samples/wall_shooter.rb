require 'rrobots'
require "#{File.dirname(__FILE__)}/utils/sample"

class WallShooter
  include Robot
  include SampleUtil

  def tick events
    wall_move
    quick_shoot
  end
end
