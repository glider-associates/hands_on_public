require 'rrobots'
require "#{File.dirname(__FILE__)}/utils/sample"
require 'securerandom'

class Reaction
  include Robot
  include SampleUtil

  def gun_turned
    fire 3
  end

  def stopped
    @recent_accelerate = nil
  end

  def accelerated
    auto_stop
  end

  def turned
    turn_gun_angle = (@enemy_direction - gun_heading) % 360
    turn_gun_angle -= 360 if turn_gun_angle > 180
    turn_gun_angle += 360 if turn_gun_angle < -180
    auto_turn_gun turn_gun_angle
    unless @recent_accelerate
      random = 0.5 - (0.5 - (SecureRandom.random_number + SecureRandom.random_number + SecureRandom.random_number)/3).abs
      random = ((SecureRandom.random_number < 0.5) ? random : -random)
      @recent_accelerate = random * 50
      auto_accelerate @recent_accelerate
    end
  end

  def crashed_into_wall(events)
    if @recent_accelerate < 0
      @recent_accelerate = 50
    else
      @recent_accelerate = -50
    end
    auto_accelerate @recent_accelerate
  end

  def scanned(robots)
    robot = robots.reject{|a| team_members.include? a[:name]}.first
    return unless robot
    @turn_radar_angle *= -1
    auto_turn_radar @turn_radar_angle
    @enemy_direction = robot[:direction]
    if @enemy_energy.to_f > robot[:energy]
      turn_angle = (@enemy_direction + 90 - heading) % 360
      turn_angle -= 360 if turn_angle > 180
      turn_angle += 360 if turn_angle < -180
      auto_turn turn_angle
    end
    turn_gun_angle = (@enemy_direction - gun_heading) % 360
    turn_gun_angle -= 360 if turn_gun_angle > 180
    turn_gun_angle += 360 if turn_gun_angle < -180
    auto_turn_gun turn_gun_angle
    @enemy_energy = robot[:energy]
    if @enemy_energy <= 0.3
      fire 3
    end
  end

  def tick events
    unless @first
      @first = true
      @enable_callbacks = true
      @turn_radar_angle = 360 * 3
      auto_turn_radar @turn_radar_angle
    end
  end
end
