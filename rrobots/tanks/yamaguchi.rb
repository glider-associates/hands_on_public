require 'rrobots'
require 'matrix'
require 'logger'

class Yamaguchi
  include Robot

  BULLET_VELOCITY = 30
  MAX_ANGLE_OF_RADAR = 60
  MIN_ANGLE_OF_RADAR = -60
  MAX_ANGLE_OF_GUN = 30
  MIN_ANGLE_OF_GUN = -30
  MAX_ANGLE_OF_ROBO = 10
  MIN_ANGLE_OF_ROBO = -10
  MAX_ROBO_VELOCITY = 8
  MIN_ROBO_VELOCITY = -8
  ANALYSIS_TICK = 18
  ROBO_SIZE = 60
  ASSALT_ATACK_ENERGY_THRESHOLD = 1.0
  ZONBI_ENERGY_THRESHOLD = 0.3

  def initialize
    @logger = Logger.new(STDOUT)
    @logs_by_robo = {}
    @gravity_point = {}
    @expected_hit_points = []
    @received_shot_points = []
    @got_hit_logs = []
    @expected_x_points = []
    @expected_y_points = []
    @hit_bullet_logs = []
    @alignment_x = nil
    @alignment_y = nil
    @attack_preparation_period = 0
    @turn_radar_direction = MAX_ANGLE_OF_GUN
    @turn_gun_direction = 0
    @turn_direction = 0
    @acceleration = 1
    @attack_mode = nil
    @will_fire = false
    @already_first_shot = false
    @avoid_point_by_pattern = {
      one_progress: {score: 0, length: ROBO_SIZE},
      two_progress: {score: 0, length: ROBO_SIZE * 2},
      one_back: {score: 0, length: ROBO_SIZE * -1},
    }
    @attack_ratio_by_pattern = {
      kamikaze: {shot: 0.0, hit: 0.0},
      pattern: {shot: 0.0, hit: 0.0},
      reaction: {shot: 0.0, hit: 0.0},
    }
  end

  def tick(events)
    attack
    push_logs
    set_run_params
    set_attack_params
    move
  end

  def push_logs
    if events['robot_scanned'].empty?
      @turn_radar_direction = (0 < @turn_radar_direction ? MAX_ANGLE_OF_RADAR : MIN_ANGLE_OF_RADAR)
    else
      events['robot_scanned'].each do |robot_scanned|
        robo_name = robot_scanned[:name]
        @logs_by_robo[robo_name] ||=  []
        @logs_by_robo[robo_name] << robot_scanned
        @logs_by_robo[robo_name].last[:time] = time
        @logs_by_robo[robo_name].last[:x] = x + Math::cos(@logs_by_robo[robo_name].last[:direction].to_rad) * @logs_by_robo[robo_name].last[:distance]
        @logs_by_robo[robo_name].last[:y] = battlefield_height - (y - Math::sin(@logs_by_robo[robo_name].last[:direction].to_rad) * @logs_by_robo[robo_name].last[:distance])
        if @logs_by_robo[robo_name].size > 1
          dt = @logs_by_robo[robo_name].last[:time] - @logs_by_robo[robo_name][-2][:time]
          @logs_by_robo[robo_name].last[:velocity] = Math::hypot(@logs_by_robo[robo_name].last[:x] - @logs_by_robo[robo_name][-2][:x], @logs_by_robo[robo_name].last[:y] - @logs_by_robo[robo_name][-2][:y]) / dt
          @logs_by_robo[robo_name].last[:heading] = diff_direction({x: @logs_by_robo[robo_name][-2][:x], y: @logs_by_robo[robo_name][-2][:y]}, {x: @logs_by_robo[robo_name].last[:x], y: @logs_by_robo[robo_name].last[:y]})
          if @logs_by_robo[robo_name].last[:velocity] and @logs_by_robo[robo_name][-2][:velocity]
            @logs_by_robo[robo_name].last[:acceleration] = @logs_by_robo[robo_name].last[:velocity] - @logs_by_robo[robo_name][-2][:velocity] / dt
            @logs_by_robo[robo_name].last[:angular_velocity] = optimize_angle(@logs_by_robo[robo_name].last[:heading] - @logs_by_robo[robo_name][-2][:heading] / dt)
          end
        end
        arrived_bullet_info = @expected_hit_points.select{ |info| info[:robo_name] == robo_name and info[:time] == time}.first
        if arrived_bullet_info
          @diff_x = @logs_by_robo[robo_name].last[:x] - arrived_bullet_info[:before_x]
          @diff_y = @logs_by_robo[robo_name].last[:y] - arrived_bullet_info[:before_y]
        end
        passed_bullet_info = @expected_hit_points.select{ |info| info[:robo_name] == robo_name and (info[:time] + 6 == time)}.first
        if passed_bullet_info and @hit_bullet_logs.any?{ |hit_bullet_log| hit_bullet_log[:time] > passed_bullet_info[:time] - 12 }
          @attack_ratio_by_pattern[passed_bullet_info[:attack_mode]][:hit] += 1
        end
      end
    end
    hit_log = events['hit'].first
    if hit_log
      hit_log[:time] = time
      @hit_bullet_logs << hit_log
    end
    got_hit_log = events['got_hit'].first
    if got_hit_log
      got_hit_log[:time] = time
      @got_hit_logs << got_hit_log
    end
    arrived_shot = @received_shot_points.select{ |received_shot| time == received_shot[:arrival_time] + 15 }.first
    if arrived_shot
      if @got_hit_logs.any?{ |got_hit_log| got_hit_log[:time] > arrived_shot[:arrival_time] - 30 }
        @avoid_point_by_pattern[arrived_shot[:avoid_pattern]][:score] += @avoid_point_by_pattern.keys.size
      else
        @avoid_point_by_pattern[arrived_shot[:avoid_pattern]][:score] -= 0.5
      end
    end
  end

  def set_run_params
    @x_gravity = 0
    @y_gravity = 0
    target = @logs_by_robo.map { |robo_name, logs| time == logs.last[:time] ? [robo_name, logs.last] : nil }.compact.min_by { |robo_name, log| log[:distance] }
    if target
      logs = @logs_by_robo[target.first]
      if logs.size > ANALYSIS_TICK
        hit_bonus = 0
        got_hit = events['got_hit'].first
        hit_bonus = got_hit[:damage] * 2/3 if got_hit
        @target_angle = diff_direction({x: x, y: (battlefield_height - y)}, {x: logs.last[:x], y: logs.last[:y]})
        diff_energy = logs[-2][:energy] - logs.last[:energy] + hit_bonus
        if (0.5..3).cover? diff_energy
          min_score = 1000
          @avoid_point_by_pattern.each do |key, value|
            min_score = value[:score] if min_score > value[:score]
          end
          avoid_pattern = @avoid_point_by_pattern.select{ |key, value| value[:score] == min_score }.keys.sample
          direction = diff_direction( {x: x, y: battlefield_height - y}, {x: logs.last[:x], y: logs.last[:y]} )
          my_heading = @acceleration > 0 ? heading : heading + 180
          direction = ((direction + 90) - my_heading).abs < ((direction - 90) - my_heading).abs ? direction + 90 : direction - 90
          avoid_x = x + @avoid_point_by_pattern[avoid_pattern][:length] * Math::cos((optimize_angle(direction)).to_rad)
          avoid_y = (battlefield_height - y) + @avoid_point_by_pattern[avoid_pattern][:length] * Math::sin((optimize_angle(direction)).to_rad)
          arrival_time = time + (Math::hypot(logs.last[:x] - avoid_x, logs.last[:y] - (battlefield_height - avoid_y)) / BULLET_VELOCITY).round
          if Math::hypot(logs.last[:x] - x, logs.last[:y] - (battlefield_height - y)) > 400
            @received_shot_points << {
              time: time,
              x: x,
              y: battlefield_height - y,
              arrival_time: arrival_time,
              avoid_pattern: avoid_pattern,
            }
          end
        end
      end
    end
    @logs_by_robo.each do |name, logs|
      if logs.last[:energy].to_f > ASSALT_ATACK_ENERGY_THRESHOLD
        @gravity_point[name] = {
          x: logs.last[:x],
          y: logs.last[:y],
          power: 200,
          expire: time,
        }
      end
    end
    if avoid_x and avoid_y
      @gravity_point['avoid'] = {
        x: avoid_x,
        y: avoid_y,
        power: -20,
        expire: arrival_time + 6,
      }
    elsif rand < 0.005 and @target_angle
      dir = (rand < 0.5 ? 1: -1)
      @gravity_point['random'] = {
        x: x + 100 * Math::cos((optimize_angle(@target_angle + 90)).to_rad) * dir,
        y: (battlefield_height - y) + 100 * Math::sin((optimize_angle(@target_angle + 90)).to_rad) * dir,
        power: 10,
        expire: time + 8,
      }
    end
    if @logs_by_robo[@aim] and @logs_by_robo[@aim].last[:energy].to_f < ASSALT_ATACK_ENERGY_THRESHOLD
      @gravity_point[@aim] = {
        x: @logs_by_robo[@aim].last[:x],
        y: @logs_by_robo[@aim].last[:y],
        power: -200,
        expire: time
      }
      if @logs_by_robo[@aim] and @logs_by_robo[@aim].last[:energy].to_f > ZONBI_ENERGY_THRESHOLD
        dir = (rand < 0.5 ? 1: -1)
        @gravity_point['random'] = {
          x: x + 100 * Math::cos((optimize_angle(@target_angle + 90)).to_rad) * dir,
          y: (battlefield_height - y) + 100 * Math::sin((optimize_angle(@target_angle + 90)).to_rad) * dir,
          power: 10,
          expire: time
        }
      end
    end
    @gravity_point[:top_wall] = {
        x: x,
        y: battlefield_height,
        power: 100,
        expire: time
      }
    @gravity_point[:bottom_wall] = {
        x: x,
        y: 0,
        power: 100,
        expire: time
      }
    @gravity_point[:left_wall] = {
        x: 0,
        y: battlefield_height - y,
        power: 100,
        expire: time
      }
    @gravity_point[:right_wall] = {
        x: battlefield_width,
        y: battlefield_height - y,
        power: 100,
        expire: time
      }
    @gravity_point.each do |name, gravity|
      next if gravity[:expire] < time
      distance = Math::hypot(gravity[:x] - x, gravity[:y] - (battlefield_height - y))
      distance = 1 if distance < 1
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
    target = @logs_by_robo.map { |robo_name, logs| time == logs.last[:time] ? [robo_name, logs.last] : nil }.compact.min_by { |robo_name, log| log[:distance] }
    return if !target
    @distance = target.last[:distance]
    @aim = target.first
    set_attack_params_for_kamikaze if @distance < 400 or !@already_first_shot
    set_attack_params_by_pattern if (!@attack_mode or @attack_mode == :pattern) and bad_attack_mode != :pattern
    set_attack_params_by_reaction if !@attack_mode and bad_attack_mode != :reaction
    if @attack_mode and @alignment_x and @alignment_y
      @attack_preparation_period += 1
      @turn_gun_direction = optimize_angle(diff_direction( {x: x, y: battlefield_height - y}, {x: @alignment_x, y: @alignment_y} ) - gun_heading - @turn_direction)
      time_to_be_hit = Math::hypot(@alignment_x - x, @alignment_y - (battlefield_height - y)) / BULLET_VELOCITY
      if @alignment_time and (time + time_to_be_hit > @alignment_time + 2)
        reset_aim
      elsif (!@alignment_time or time + time_to_be_hit > @alignment_time) and ((@distance < 400 and @turn_gun_direction.abs < 15) or @turn_gun_direction.abs < 5) and gun_heat == 0
        @will_fire = true
        @expected_hit_points << {
          robo_name: @aim,
          time: (time + time_to_be_hit).round,
          before_x: @logs_by_robo[@aim].last[:x],
          before_y: @logs_by_robo[@aim].last[:y],
          attack_mode: @attack_mode,
        }
        @attack_ratio_by_pattern[@attack_mode][:shot] += 1
      end
      @turn_gun_direction = round_whithin_range @turn_gun_direction, MIN_ANGLE_OF_GUN..MAX_ANGLE_OF_GUN
    end
  end

  def set_attack_params_for_kamikaze
    last_log = @logs_by_robo[@aim].last
    return if !last_log || !last_log[:heading] || !last_log[:angular_velocity]
    reset_aim
    adjust_tick = (@distance / 80)
    _heading = optimize_angle(last_log[:heading] + last_log[:angular_velocity] * adjust_tick)
    @alignment_x = last_log[:x] + (last_log[:velocity] * Math::cos(_heading.to_rad)) * adjust_tick
    @alignment_y = last_log[:y] + (last_log[:velocity] * Math::sin(_heading.to_rad)) * adjust_tick
    @attack_mode = :kamikaze
  end

  def set_attack_params_by_pattern
    logs = @logs_by_robo[@aim].last(1000)
    if !@alignment_x || !@alignment_y || (@expected_y_points[@attack_preparation_period - 1] and Math::hypot(logs.last[:x] - @expected_x_points[@attack_preparation_period - 1], logs.last[:y] - @expected_y_points[@attack_preparation_period - 1]) > 16)
      reset_aim
      return if logs.size <= ANALYSIS_TICK
      @aim_x = logs.last[:x]
      @aim_y = logs.last[:y]
      @aim_heading = logs.last[:heading]
      @aim_velocity = logs.last[:velocity]
      recent_logs = logs.last(ANALYSIS_TICK)
      similar_index = 0
      min_score = ANALYSIS_TICK * 8
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
      @expected_x_points = []
      @expected_y_points = []
      (similar_index).upto(logs.size - 1) do |index|
        after_tick = logs[index][:time] - similar_time
        @alignment_time = time + after_tick
        @aim_heading += logs[index][:angular_velocity]
        @aim_heading = optimize_angle(@aim_heading)
        @aim_velocity += logs[index][:acceleration]
        @aim_velocity = round_whithin_range @aim_velocity, MIN_ROBO_VELOCITY..MAX_ROBO_VELOCITY
        @aim_x += @aim_velocity * Math::cos(@aim_heading.to_rad)
        @expected_x_points << @aim_x
        @aim_y += @aim_velocity * Math::sin(@aim_heading.to_rad)
        @expected_y_points << @aim_y
        return if @aim_x * @aim_y < 0 || @aim_x > battlefield_width || @aim_y > battlefield_height
        diff_gun_direction = diff_direction( {x: x, y: battlefield_height - y}, {x: @aim_x, y: @aim_y} ) - gun_heading
        diff_gun_direction = 180 if diff_gun_direction.abs > 180
        sighter_time = (diff_gun_direction.abs / MAX_ANGLE_OF_GUN).ceil
        distance = Math::hypot(x - @aim_x, (battlefield_height - y) - @aim_y)
        trajectory_time = (distance / BULLET_VELOCITY).ceil
        if (sighter_time + trajectory_time < after_tick) && (gun_heat * 10 < after_tick - 1)
          @alignment_x = @aim_x
          @alignment_y = @aim_y
          @attack_mode = :pattern
          break
        end
      end
    end
  end

  def set_attack_params_by_reaction
    return if !@diff_x or !@diff_y
    @alignment_x = @logs_by_robo[@aim].last[:x] + @diff_x
    @alignment_y = @logs_by_robo[@aim].last[:y] + @diff_y
    distance = Math::hypot(x - @alignment_x, (battlefield_height - y) - @alignment_y)
    trajectory_time = (distance / BULLET_VELOCITY).ceil
    @alignment_time = trajectory_time + time
    @attack_mode = :reaction
  end

  def move
    turn @turn_direction
    turn_gun @turn_gun_direction
    adjust_radar unless events['robot_scanned'].empty?
    turn_radar @turn_radar_direction
    accelerate @acceleration
  end

  def attack
    return if !@will_fire || num_robots < 2
    remaining_energy = @logs_by_robo[@aim].last[:energy]
    return if remaining_energy < ZONBI_ENERGY_THRESHOLD
    return if remaining_energy < 3.0 and @distance > 400
    @size_of_bullet = nil
    if @distance < 400
      @size_of_bullet = 3
    elsif !@already_first_shot
      @size_of_bullet = 1
    else
      @size_of_bullet = (remaining_energy > 20 ? 3 : ((remaining_energy - ZONBI_ENERGY_THRESHOLD) / 3.3) - 0.1 )
      if @attack_mode == :pattern
        @size_of_bullet = @size_of_bullet * (@attack_ratio_by_pattern[:pattern][:hit] / @attack_ratio_by_pattern[:pattern][:shot]) + 0.5
      elsif @attack_mode == :reaction
        @size_of_bullet = @size_of_bullet * (@attack_ratio_by_pattern[:reaction][:hit] / @attack_ratio_by_pattern[:reaction][:shot]) + 0.5
      end
    end
    fire @size_of_bullet
    @already_first_shot ||= true
    @will_fire = false
    reset_aim
  end

  def bad_attack_mode
    return nil if @attack_ratio_by_pattern[:pattern][:shot] < 5 or @attack_ratio_by_pattern[:reaction][:shot] < 5
    pattern_hit_ratio = @attack_ratio_by_pattern[:pattern][:hit] / @attack_ratio_by_pattern[:pattern][:shot]
    reaction_hit_ratio = @attack_ratio_by_pattern[:reaction][:hit] / @attack_ratio_by_pattern[:reaction][:shot]
    if (pattern_hit_ratio / reaction_hit_ratio) > 1.4
      :reaction
    elsif (reaction_hit_ratio / pattern_hit_ratio) > 1.2
      :pattern
    else
      nil
    end
  end

  def reset_aim
    @alignment_time = nil
    @alignment_x = nil
    @alignment_y = nil
    @attack_mode = nil
    @attack_preparation_period = 0
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
