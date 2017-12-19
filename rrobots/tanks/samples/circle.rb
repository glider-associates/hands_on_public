require 'rrobots'
class Circle
  include Robot

  def tick events
    turn_radar 1 if time == 0
    turn_gun 0
    accelerate 1
    turn 2
    fire 3 unless events['robot_scanned'].empty?
  end
end
