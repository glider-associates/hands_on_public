require 'rrobots'

require 'securerandom'
class Swing
  include Robot

  def tick events
    turn_radar 1 if time == 0
    turn_gun 2

    if time % 900 < 30
      turn 2
    end
    if (time % 80) < 40
      accelerate 1
    else
      accelerate -1
    end
    fire 3 unless events['robot_scanned'].empty?
  end
end
