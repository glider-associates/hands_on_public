require 'rrobots'
require "#{File.dirname(__FILE__)}/utils/sample"

class QuickShooter
  include Robot
  include SampleUtil

  def tick events
    if @will_fire
      fire 3
      @will_fire = false
    end

    nearest = scan_for_fire
    if nearest
      turn nearest[:diff]
      turn_gun (nearest[:diff] - 10) if nearest[:diff] * (nearest[:diff] - 10) > 0
      if nearest[:diff].abs <= 30 and gun_heat == 0
        @will_fire = true
      end
    end
  end
end
