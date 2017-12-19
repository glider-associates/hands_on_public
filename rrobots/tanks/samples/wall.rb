require 'rrobots'
require "#{File.dirname(__FILE__)}/utils/sample"

class Wall
  include Robot
  include SampleUtil

  def tick events
    turn_radar 2 if time % 2 == 1
    turn_radar -2 if time % 2 == 0
    turn_gun -15 if time < 6

    fire 3 unless events['robot_scanned'].empty?
    wall_move
  end
end
