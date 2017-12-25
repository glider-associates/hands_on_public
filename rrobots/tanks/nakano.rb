require 'securerandom'
require 'rrobots'
require 'logger'
class Nakano
  include Robot

  def set_color
    font_color 'lime'
    body_color 'lime'
    turret_color 'lime'
    radar_color 'lime'
  end

  def tick events
    set_color
    nakano_turn_radar
    nakano_turn_gun
    nakano_accelerate
      unless events['robot_scanned'].empty?
        nakano_fire
#    log = Logger.new(STDOUT)
#    log.debug events
    end

  end

  def nakano_turn_radar
    @turn_radar ||= 59
    if events['robot_scanned'].empty?
      turn_radar  @turn_radar
    else
      @turn_radar *= -1
      turn_radar  @turn_radar
    end
  end

  def enemy_direction
    unless events['robot_scanned'].empty?
      @enemy_direction = events['robot_scanned'][0][:direction]
    else
      @enemy_direction ||= 0
    end
  end

  def diff_direction_gun
    if enemy_direction > gun_heading && enemy_direction - gun_heading >= 180
      (enemy_direction - gun_heading) - 360
    elsif enemy_direction > gun_heading && enemy_direction - gun_heading < 180
      enemy_direction - gun_heading
    elsif enemy_direction < gun_heading && gun_heading - enemy_direction >= 180
      360 - (gun_heading - enemy_direction)
    elsif enemy_direction < gun_heading && gun_heading - enemy_direction < 180
      enemy_direction - gun_heading
    else
      enemy_direction - gun_heading
    end
  end

  def nakano_turn_gun
    turn_gun diff_direction_gun
  end

  def diff_direction_robot
    if enemy_direction > heading && enemy_direction - heading >= 180
      (enemy_direction - heading) - 360
    elsif enemy_direction > heading && enemy_direction - heading < 180
      enemy_direction - heading
    elsif enemy_direction < heading && heading - enemy_direction >= 180
      360 - (heading - enemy_direction)
    elsif enemy_direction < heading && heading - enemy_direction < 180
      enemy_direction - heading
    else
      enemy_direction - heading
    end
  end

  def diff_direction_robot_right_angle
    if enemy_direction > heading && enemy_direction - heading >= 180
      (enemy_direction - heading) - 360 + 45
    elsif enemy_direction > heading && enemy_direction - heading < 180
      enemy_direction - heading - 45
    elsif enemy_direction < heading && heading - enemy_direction >= 180
      360 - (heading - enemy_direction) - 45
    elsif enemy_direction < heading && heading - enemy_direction < 180
      enemy_direction - heading + 45
    else
      enemy_direction - heading
    end
  end

  def crash_wall_switch
    if events['crash_into_wall'].empty?
      @cr_wa_frag
    else
      @cr_wa_frag ^= true
    end
  end

  def hit_switch
    if events['got_hit'].empty?
      @ac_frag
    else
      @ac_frag ^= true
    end
  end

  def crash_enemy_switch
    if events['crash_into_enemy'].empty?
      @cr_en_frag
    else
      @cr_en_frag ^= false
    end
  end

  def nakano_circle
    if @cr_wa_frag
      accelerate 1
      turn 1
    else
      accelerate -1
      turn 1
    end
  end

  def nakano_swing
    if @cr_wa_frag
      accelerate 1
      turn 0
    else
      accelerate -1
      turn 0
    end
  end

  def nakano_switch_move
    if @cr_wa_frag
      nakano_circle
    else
      nakano_swing
    end
  end

  def mode_change
    if energy < 50
      @atack_mode = true
      @defence_mode = false
    else
      @atack_mode = false
      @defence_mode = true
    end
  end

  def enemy_energy
    if events['robot_scanned'].empty?
      return
    elsif @pre_enemy_energy == nil
      @pre_enemy_energy = events['robot_scanned'][0][:energy]
    else
      @diff_enemy_energy = @pre_enemy_energy - events['robot_scanned'][0][:energy]
      @pre_enemy_energy = events['robot_scanned'][0][:energy]
    end
  end

  def enemy_fired
    if events['robot_scanned'].empty?
      false
    elsif (0.1..3).include?(@diff_enemy_energy)
      true
    else
      false
    end
  end

  def atack_move
    if events['robot_scanned'][0][:distance] < 100
      accelerate -1
      turn diff_direction_robot_right_angle
    elsif x <= battlefield_width / 2 && y <= battlefield_height / 2
      @accelerate ||= 1
        if (time % 20) == 0 and SecureRandom.random_number < 0.5
         @accelerate *= -1
        end
      accelerate @accelerate
      turn diff_direction_robot_right_angle
    elsif  x > battlefield_width / 2 && y <= battlefield_height / 2
      @accelerate ||= 1
        if (time % 20) == 0 and SecureRandom.random_number < 0.5
         @accelerate *= -1
        end
      accelerate @accelerate
      turn rand(1..5)
    elsif  x > battlefield_width / 2 && y > battlefield_height / 2
      @accelerate ||= 1
        if (time % 20) == 0 and SecureRandom.random_number < 0.5
         @accelerate *= -1
        end
      accelerate @accelerate
      turn diff_direction_robot + 90
    elsif x <= battlefield_width / 2 && y > battlefield_height / 2
      @accelerate ||= 1
        if (time % 20) == 0 and SecureRandom.random_number < 0.5
         @accelerate *= -1
        end
      accelerate @accelerate
      turn rand(6..10)
    end
  end

 def defence_move
   if enemy_fired
     @accelerate ||= 1
       if (time % 10) == 0 and SecureRandom.random_number < 0.5
        @accelerate *= -1
       end
     accelerate @accelerate
   else
     @accelerate ||= 1
       if (time % 10) == 0 and SecureRandom.random_number < 0.5
        @accelerate *= -1
       end
     accelerate @accelerate
     turn diff_direction_robot + 90
   end
 end

  def final_atack
    accelerate 1
    turn diff_direction_robot
  end

  def nakano_accelerate
    hit_switch
    crash_wall_switch
    crash_enemy_switch
    mode_change
    enemy_energy
    enemy_fired
    if events['robot_scanned'].empty?
      @accelerate ||= 1
      accelerate @accelerate
    elsif events['robot_scanned'][0][:energy] < 1 && events['robot_scanned'][0][:energy] > 0 && energy > 10
      final_atack
    elsif @atack_mode
      atack_move
    elsif @defence_mode
      defence_move
    end
  end

  def gun_range
    unless events['robot_scanned'].empty?
      @gun_range = 180 - 2 * (Math.atan(events['robot_scanned'][0][:distance] / 30))
    else
      @gun_range = 2000
    end
  end

   def nakano_fire
      if diff_direction_gun <= gun_range && events['robot_scanned'][0][:energy] > 10 && events['robot_scanned'][0][:distance] <= 300
        fire 3
      elsif diff_direction_gun <= gun_range && events['robot_scanned'][0][:energy] > 10 && energy > 30 && events['robot_scanned'][0][:distance] > 300
        fire 1.1
      elsif diff_direction_gun <= gun_range && events['robot_scanned'][0][:energy] > 1 && energy > 30
        @zero_fire = events['robot_scanned'][0][:energy] / 23.1
        fire @zero_fire
      elsif diff_direction_gun <= gun_range && events['robot_scanned'][0][:energy] > 1 && energy <= 30
        fire 1.1
      elsif diff_direction_gun <= gun_range && events['robot_scanned'][0][:energy] < 1 && events['robot_scanned'][0][:energy] > 0 && energy <= 10
        fire 1.1
      else
        fire 0
      end
   end

end
