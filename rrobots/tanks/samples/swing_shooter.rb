require 'rrobots'
require "#{File.dirname(__FILE__)}/utils/sample"

require 'securerandom'

class SwingShooter
  include Robot
  include SampleUtil

  def tick events
    if time % 900 < 30
      turn 2
    end
    if (time % 80) < 40
      accelerate 1
    else
      accelerate -1
    end
    quick_shoot
  end
end
