require 'rrobots'
class Sakabayashi
  include Robot

  def quick_one
    turn_radar 45
    if @will_fire
      fire 3
      @will_fire = false
    end
    events['robot_scanned'].each{|scanned|
      diff = (scanned[:direction] - gun_heading) % 360
      diff -= 360 if diff > 180
      diff += 360 if diff < -180
      if diff.abs <= 30 and gun_heat == 0
        @will_fire = true
        turn_gun diff
        break
      end
    }
    turn_gun 30 unless @will_fire
  end

  def tick events
    turn_gun 0
    accelerate 1
    turn 2
    quick_one
  end
end
