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
    end
    log = Logger.new(STDOUT)
    log.debug [enemy_direction,heading,diff_direction_robot_right_angle]
  end

  def nakano_turn_radar
    @turn_radar ||= 60
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
    if @cr_en_frag
      nakano_circle
    else
      nakano_swing
    end
  end

  def mode_change
    if energy > 50
      @atack_mode = true
      @defence_mode = false
    else
      @atack_mode = false
      @defence_mode = true
    end
  end

  def enemy_distance
    if events['robot_scanned'].empty?
      return
    elsif events['robot_scanned'][0][:direction] < 100
      @near
    else
      @near ^= true
    end
  end

  def final_atack
      while events['crash_into_enemy'].empty? do
      nakano_turn_radar
      accelerate 1
      turn diff_direction_robot
      if events['crash_into_enemy'] = true
        break
      end
      end
  end

  def nakano_accelerate
    hit_switch
    crash_wall_switch
    crash_enemy_switch
    enemy_distance
    mode_change
    if events['robot_scanned'].empty?
      accelerate 0
      turn 0
    elsif events['robot_scanned'][0][:energy] < 1 && events['robot_scanned'][0][:energy] > 0 && energy > 10
      final_atack
    elsif @atack_mode
      accelerate 1
      turn diff_direction_robot_right_angle
    elsif @defence_mode
      nakano_circle
    else
      nakano_circle
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
      if diff_direction_gun <= gun_range && events['robot_scanned'][0][:energy] > 10 && energy > 30
        fire 3
      elsif diff_direction_gun <= gun_range && events['robot_scanned'][0][:energy] > 1 && energy > 30
        fire 0.1
      elsif diff_direction_gun <= gun_range && events['robot_scanned'][0][:energy] > 1
        fire 3
      elsif events['robot_scanned'][0][:energy] < 1 && events['robot_scanned'][0][:energy] > 0 && energy > 10
        fire 1
      else
        fire 0
      end
   end

end
