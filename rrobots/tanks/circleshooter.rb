require 'rrobots'
require "#{File.dirname(__FILE__)}/utils/shooter"

class Circleshooter
  include Robot
  include ShooterUtil

  def tick events
    accelerate 1
    turn 2
    quick_shoot
  end
end
