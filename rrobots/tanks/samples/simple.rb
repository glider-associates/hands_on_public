require 'rrobots'
class Simple
  include Robot

  def tick events
    turn_radar 2 if time == 0
    turn_gun 3
    fire 3 unless events['robot_scanned'].empty?
  end
end
