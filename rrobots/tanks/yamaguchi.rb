require 'rrobots'
require 'matrix'
require 'logger'

class Yamaguchi
  include Robot

  BULLET_VELOCITY = 30
  MAX_ANGLE_OF_RADAR = 60
  MAX_ANGLE_OF_GUN = 30
  MIN_ANGLE_OF_GUN = -30
  MAX_ANGLE_OF_ROBO = 10
  MIN_ANGLE_OF_ROBO = -10
  MAX_ROBO_VELOCITY = 8
  MIN_ROBO_VELOCITY = -8
  ASSALT_ATTACK_ENERGY_THRESHOLD = 1.0
  ANALYSIS_TICK = 18

  def initialize
    @logg = Logger.new(STDOUT)
    @log_by_robo = {}
    @turn_radar_direction = MAX_ANGLE_OF_GUN
    @turn_gun_direction = 0
    @turn_direction = 0
    @acceleration = 1
    @avoid_angle = 90
    @gravity_by_points = {}
    @alignment_x = nil
    @alignment_y = nil
    @expected_xs = []
    @expected_ys = []
    @attack_preparation_period = 0
    @expected_hits = []
    @attack_mode = nil
  end

  def tick(events)
    push_logs
    set_run_params
    set_attack_params
    run
    attack
  end

  def push_logs
    if events['robot_scanned'].empty?
      @turn_radar_direction = (0 < @turn_radar_direction ? 1 : -1) * MAX_ANGLE_OF_RADAR
    else
      events['robot_scanned'].each do |robot_scanned|
        robo_name = robot_scanned[:name]
        @log_by_robo[robo_name] ||=  []
        @log_by_robo[robo_name] << robot_scanned
        @log_by_robo[robo_name].last[:time] = time
        @log_by_robo[robo_name].last[:my_x] = x
        @log_by_robo[robo_name].last[:my_y] = battlefield_height - y
        @log_by_robo[robo_name].last[:x] = x + Math::cos(@log_by_robo[robo_name].last[:direction].to_rad) * @log_by_robo[robo_name].last[:distance]
        @log_by_robo[robo_name].last[:y] = battlefield_height - (y - Math::sin(@log_by_robo[robo_name].last[:direction].to_rad) * @log_by_robo[robo_name].last[:distance])
        if @log_by_robo[robo_name].size > 1
          dt = @log_by_robo[robo_name].last[:time] - @log_by_robo[robo_name][-2][:time]
          @log_by_robo[robo_name].last[:velocity] = Math::hypot(@log_by_robo[robo_name].last[:x] - @log_by_robo[robo_name][-2][:x], @log_by_robo[robo_name].last[:y] - @log_by_robo[robo_name][-2][:y]) / dt
          @log_by_robo[robo_name].last[:heading] = diff_direction({x: @log_by_robo[robo_name][-2][:x], y: @log_by_robo[robo_name][-2][:y]}, {x: @log_by_robo[robo_name].last[:x], y: @log_by_robo[robo_name].last[:y]})
          if @log_by_robo[robo_name].last[:velocity] and @log_by_robo[robo_name][-2][:velocity]
            @log_by_robo[robo_name].last[:acceleration] = @log_by_robo[robo_name].last[:velocity] - @log_by_robo[robo_name][-2][:velocity] / dt
            @log_by_robo[robo_name].last[:angular_velocity] = optimize_angle(@log_by_robo[robo_name].last[:heading] - @log_by_robo[robo_name][-2][:heading] / dt)
          end
        end
        expected_hit = @expected_hits.select{ |info| info[:robo] == robo_name and info[:time] == time}.first
        expected_hit[:diff_x] = @log_by_robo[robo_name].last[:x] - expected_hit[:pre_x]
        expected_hit[:diff_y] = @log_by_robo[robo_name].last[:y] - expected_hit[:pre_y]
      end
    end
  end

  def set_run_params
    @x_gravity = 0
    @y_gravity = 0
    @avoid_angle *= -1 if rand < 0.6 unless events['got_hit'].empty?
    @recent_logs = @log_by_robo.map { |name, logs| (time - logs.last[:time]) < 6 ? logs.last : nil }.compact
    unless @recent_logs.empty?
      @recent_logs.each do |log|
        hit_bonus = 0
        next if log.size < 10
        got_hit = events['got_hit'].select { |hit_log| hit_log[:from] == log[:name] }.first
        hit_bonus = got_hit[:damage] * 2/3 if got_hit
        @target_angle = diff_direction({x: x, y: (battlefield_height - y)}, {x: log[:x], y: log[:y]})
        diff_energy = @log_by_robo[log[:name]][-2][:energy] - log[:energy] + hit_bonus
        @avoid_angle *= -1 if (0.1..3).cover? diff_energy and rand < 0.6
      end
    end
    @log_by_robo.each do |name, logs|
      @gravity_by_points[name] = {
        x: logs.last[:x],
        y: logs.last[:y],
        power: 80,
        expire: logs.last[:time] + 1
      }
    end
    @avoid_angle *= -1 if rand < 0.05
    if @target_angle
      @gravity_by_points['randam'] = {
        x: x + 100 * Math::cos((optimize_angle(@target_angle + @avoid_angle)).to_rad),
        y: (battlefield_height - y) + 100 * Math::sin((optimize_angle(@target_angle + @avoid_angle)).to_rad),
        power: 10,
        expire: time + 1
      }
    end
    if @log_by_robo[@aim] and @log_by_robo[@aim].last[:energy].to_f < 1
      @gravity_by_points[@aim] = {
        x: @log_by_robo[@aim].last[:x],
        y: @log_by_robo[@aim].last[:y],
        power: -1000,
        expire: time + 1
      }
    end
    @gravity_by_points[:top_wall] = {
        x: x,
        y: battlefield_height,
        power: 10,
        expire: time + 1
      }
    @gravity_by_points[:bottom_wall] = {
        x: x,
        y: 0,
        power: 10,
        expire: time + 1
      }
    @gravity_by_points[:left_wall] = {
        x: 0,
        y: battlefield_height - y,
        power: 10,
        expire: time + 1
      }
    @gravity_by_points[:right_wall] = {
        x: battlefield_width,
        y: battlefield_height - y,
        power: 10,
        expire: time + 1
      }
    @gravity_by_points.each do |name, gravity|
      next if gravity[:expire] < time
      distance = Math::hypot(gravity[:x] - x, gravity[:y] - (battlefield_height - y))
      direction = diff_direction({x: gravity[:x], y: gravity[:y]}, {x: x, y: (battlefield_height - y)})
      @x_gravity += (gravity[:power] * Math.cos(direction.to_rad)) / distance ** 2
      @y_gravity += (gravity[:power] * Math.sin(direction.to_rad)) / distance ** 2
    end
    @turn_direction = optimize_angle(diff_direction({x:0, y:0}, {x:@x_gravity, y:@y_gravity}) - heading)
    if 90 < @turn_direction.abs
      @acceleration = -1
      @turn_direction += (0 < @turn_direction ? -180 : 180)
    else
      @acceleration = 1
    end
    @turn_direction = round_whithin_range @turn_direction, MIN_ANGLE_OF_ROBO..MAX_ANGLE_OF_ROBO
  end

  def set_attack_params
    target = @log_by_robo.map { |robo_name, logs| time == logs.last[:time] ? [robo_name, logs.last] : nil }.compact.min_by { |robo_name, log| log[:distance] }
    return if !target
    @short_distance = target.last[:distance] < 300
    @aim = target.first
    set_attack_params_for_kamikaze
    if !@attack_mode || @attack_mode == :pattern
      set_attack_params_by_pattern
    end
    if !@attack_mode || @attack_mode == :dodge
      set_attack_params_by_dodge_bullet
    end
    if @alignment_x and @alignment_y
      @attack_preparation_period += 1
      @turn_gun_direction = optimize_angle(diff_direction( {x: x, y: battlefield_height - y}, {x: @alignment_x, y: @alignment_y} ) - gun_heading - @turn_direction)
      time_to_be_hit = Math::hypot(@alignment_x - x, @alignment_y - (battlefield_height - y)) / BULLET_VELOCITY
      if (time + time_to_be_hit > @alignment_time + 1) and @turn_gun_direction.abs <= MAX_ANGLE_OF_GUN and gun_heat < 0.1
        @will_fire = true
        @expected_hits << {
          robo: @aim,
          time: (time + time_to_be_hit).round,
          pre_x: @log_by_robo[@aim].last[:x],
          pre_y: @log_by_robo[@aim].last[:y],
        }
      end
      @turn_gun_direction = round_whithin_range @turn_gun_direction, MIN_ANGLE_OF_GUN..MAX_ANGLE_OF_GUN
    end
  end

  def set_attack_params_for_kamikaze
    logs = @log_by_robo[@aim]
    return if logs.size < 8
    dist = 0
    -7.upto(-1) do |index|
      dist += (Math::hypot(logs[index - 1][:my_x] - logs[index][:x], logs[index - 1][:my_y] - logs[index][:y]) - Math::hypot(logs[index - 1][:my_x] - logs[index - 1][:x], logs[index - 1][:my_y] - logs[index - 1][:y]))
    end
    if dist < -30 || @short_distance
      @alignment_time = time
      @alignment_x = logs.last[:x]
      @alignment_y = logs.last[:y]
      @attack_mode = :kamikaze
    end
  end

  def set_attack_params_by_pattern
    logs = @log_by_robo[@aim].last(1000)
    if !@alignment_x || !@alignment_y || (@expected_ys[@attack_preparation_period - 1] and Math::hypot(logs.last[:x] - @expected_xs[@attack_preparation_period - 1], logs.last[:y] - @expected_ys[@attack_preparation_period - 1]) > 8)
      @alignment_x = @alignment_y = nil
      @attack_mode = nil
      return if logs.size < 20
      @aim_x = logs.last[:x]
      @aim_y = logs.last[:y]
      @aim_heading = logs.last[:heading]
      @aim_velocity = logs.last[:velocity]
      recent_logs = logs.last(ANALYSIS_TICK)
      similar_index = 0
      min_score = 30
      similar_time = nil
      (logs.size - ANALYSIS_TICK - 1).times do |i|
        next if !logs[i][:angular_velocity] || !logs[i][:acceleration]
        score = 0
        recent_logs.each_with_index do |recent_log, j|
          score += (recent_log[:angular_velocity] - logs[i+j][:angular_velocity]).abs + (recent_log[:acceleration] - logs[i+j][:acceleration]).abs
        end
        if score < min_score
          min_score = score
          similar_index = i + ANALYSIS_TICK
          similar_time = logs[similar_index][:time]
        end
      end
      return if !similar_time
      @expected_xs = []
      @expected_ys = []
      (similar_index).upto(logs.size - 1) do |index|
        after_tick = logs[index][:time] - similar_time
        @alignment_time = time + after_tick
        @aim_heading += logs[index][:angular_velocity]
        @aim_heading = optimize_angle(@aim_heading)
        @aim_velocity += logs[index][:acceleration]
        @aim_velocity = round_whithin_range @aim_velocity, MIN_ROBO_VELOCITY..MAX_ROBO_VELOCITY
        @aim_x += @aim_velocity * Math::cos(@aim_heading.to_rad)
        @expected_xs << @aim_x
        @aim_y += @aim_velocity * Math::sin(@aim_heading.to_rad)
        @expected_ys << @aim_y
        return if @aim_x * @aim_y < 0 || @aim_x > battlefield_width || @aim_y > battlefield_height
        diff_gun_direction = diff_direction( {x: x, y: battlefield_height - y}, {x: @aim_x, y: @aim_y} ) - gun_heading
        diff_gun_direction = 180 if diff_gun_direction.abs > 180
        sighter_time = (diff_gun_direction.abs / (MAX_ANGLE_OF_GUN - (MAX_ANGLE_OF_ROBO/2))).ceil
        distance = Math::hypot(x - @aim_x, (battlefield_height - y) - @aim_y)
        trajectory_time = (distance / (BULLET_VELOCITY - (MAX_ROBO_VELOCITY/2))).ceil
        if (sighter_time + trajectory_time < after_tick) && (gun_heat * 10 < after_tick)
          @alignment_x = @aim_x
          @alignment_y = @aim_y
          @attack_mode = :pattern
          break
        end
      end
    end
  end

  def set_attack_params_by_dodge_bullet
    dodge_point = @expected_hits.select{ |expected_hit| expected_hit[:robo] == @aim and expected_hit[:diff_x] and expected_hit[:diff_y] }.max_by { |expected_hit| expected_hit[:time] }
    return unless dodge_point
    @alignment_time = time
    @alignment_x = @log_by_robo[@aim].last[:x] + dodge_point[:diff_x]
    @alignment_y = @log_by_robo[@aim].last[:y] + dodge_point[:diff_y]
    @attack_mode = :dodge
  end

  def run
    turn @turn_direction
    turn_gun @turn_gun_direction
    adjust_radar unless events['robot_scanned'].empty?
    turn_radar @turn_radar_direction
    accelerate @acceleration
  end

  def attack
    return if !@will_fire || num_robots < 2
    remaining_energy = @log_by_robo[@aim].last[:energy]
    return if remaining_energy < ASSALT_ATTACK_ENERGY_THRESHOLD
    @size_of_bullet = nil
    @size_of_bullet = 3 if @short_distance
    @size_of_bullet = 1 if remaining_energy < 1 && energy < 8
    @size_of_bullet ||= (remaining_energy > 20 ? 3 : remaining_energy/3.3 - ASSALT_ATTACK_ENERGY_THRESHOLD)
    fire @size_of_bullet
    @will_fire = false
    @attack_preparation_period = 0
    @alignment_x = nil
    @alignment_y = nil
    @attack_mode = nil
  end

  def adjust_radar
    diff_radar_direction = events['robot_scanned'].min_by { |log| log[:distance] }[:direction] - radar_heading
    @turn_radar_direction = optimize_angle(diff_radar_direction) * 2
    @turn_radar_direction -= (@turn_direction + @turn_gun_direction)
    optimize_angle(@turn_radar_direction)
  end

  def diff_direction(observation, target)
    if target[:x] == observation[:x]
      return target[:y] - observation[:y] > 0 ? 90 : 270
    end
    direction = to_angle(Math::atan( (target[:y] - observation[:y]) / (target[:x] - observation[:x]) ))
    direction += 180 if (target[:x] - observation[:x]) < 0
    direction += 360 if direction < 0
    direction
  end

  def to_angle(radian)
    radian * 180 / Math::PI
  end

  def round_whithin_range(value, range)
    return range.first if range.first > value
    return range.last if range.last < value
    value
  end

  def optimize_angle(angle)
    angle += 360 if 0 > angle
    angle -= 360 if 180 < angle
    angle
  end
end
