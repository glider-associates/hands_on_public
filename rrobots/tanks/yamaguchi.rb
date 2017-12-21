# right, left
# strategy同時検証

require 'rrobots'
require 'matrix'

require 'logger'

class Yamaguchi
  include Robot

  BULLET_SPEED = 30
  MAX_ANGLE_OF_RADAR = 60
  MAX_ANGLE_OF_RUN = 30
  MAX_ROBO_SPEED = 8
  MIN_ROBO_SPEED = -8

  def initialize
    @logg = Logger.new(STDOUT)
    @attack_strategy ||= {
      direct: {tries: 10.0, hit: 1.0},
      uniform_acceleration: {tries: 10.0, hit: 1.0},
      # right: 1,
      # left: 1
    }
  end

  def tick(events)
    @got_hit_log = {} if time == 0
    @log_by_robo = {} if time == 0
    @targets = [] if time == 0
    if @will_fire and num_robots > 1
      @will_fire = false
      @size_of_bullet = (@log_by_robo[@aim].last[:energy] > 20 ? 3 : @log_by_robo[@aim].last[:energy]/3.3 - 0.1)
      @size_of_bullet = 1 if @long_distance
      fire @size_of_bullet
    end
    get_enemies_info
    @turn_radar_direction = round_whithin_range @turn_radar_direction, -60..60
    set_run_params
    @turn_direction = round_whithin_range @turn_direction, -10..10
    set_attack_params
    turn @turn_direction
    turn_gun @turn_gun_direction
    if @adjust_radar
      @turn_radar_direction -= @turn_direction
      @turn_radar_direction -= @turn_gun_direction
      @adjust_radar = false
    end
    turn_radar optimize_angle optimize_angle @turn_radar_direction
    accelerate @acceleration
  end

  def get_enemies_info
    @turn_radar_direction ||= MAX_ANGLE_OF_RADAR
    @turn_gun_direction ||= MAX_ANGLE_OF_RUN
    unless events['got_hit'].empty?
      @got_hit_log[events['got_hit'].first[:from]] ||= []
      @got_hit_log[events['got_hit'].first[:from]].delete_if { |hit_time| time - hit_time > 60 }
      @got_hit_log[events['got_hit'].first[:from]] << time
      @emergency = events['got_hit'].first[:from] if @got_hit_log[events['got_hit'].first[:from]].size
    end
    unless events['hit'].empty?
      if expected = @expected_hits.select { |expected_hit| (time - expected_hit[:time]).abs < 30 }.first
        @attack_strategy[expected[:strategy]][:hit] += 1
      end
    end
    @singular_points = {} if time == 0
    if events['robot_scanned'].empty?
      @turn_radar_direction = (0 < @turn_radar_direction ? 1 : -1) * MAX_ANGLE_OF_RADAR
    else
      events['robot_scanned'].each do |robot_scanned|
        @log_by_robo[robot_scanned[:name]] ||=  []
        @log_by_robo[robot_scanned[:name]] << robot_scanned
        @log_by_robo[robot_scanned[:name]].last[:time] = time
        @log_by_robo[robot_scanned[:name]].last[:x] = x + Math::cos(@log_by_robo[robot_scanned[:name]].last[:direction].to_rad) * @log_by_robo[robot_scanned[:name]].last[:distance]
        @log_by_robo[robot_scanned[:name]].last[:y] = battlefield_height - (y - Math::sin(@log_by_robo[robot_scanned[:name]].last[:direction].to_rad) * @log_by_robo[robot_scanned[:name]].last[:distance])
        if @log_by_robo[robot_scanned[:name]].size > 1
          t = @log_by_robo[robot_scanned[:name]].last[:time] - @log_by_robo[robot_scanned[:name]][-2][:time]
          @log_by_robo[robot_scanned[:name]].last[:x_speed] = (@log_by_robo[robot_scanned[:name]].last[:x] - @log_by_robo[robot_scanned[:name]][-2][:x]) / t
          @log_by_robo[robot_scanned[:name]].last[:y_speed] = (@log_by_robo[robot_scanned[:name]].last[:y] - @log_by_robo[robot_scanned[:name]][-2][:y]) / t
          @log_by_robo[robot_scanned[:name]].last[:speed] = Math::hypot(@log_by_robo[robot_scanned[:name]].last[:x_speed], @log_by_robo[robot_scanned[:name]].last[:y_speed])
          @log_by_robo[robot_scanned[:name]].last[:heading] = to_angle(Math::acos(@log_by_robo[robot_scanned[:name]].last[:x_speed] / @log_by_robo[robot_scanned[:name]].last[:speed])) if @log_by_robo[robot_scanned[:name]].last[:speed] > 0
          if @log_by_robo[robot_scanned[:name]].size > 2
            @log_by_robo[robot_scanned[:name]].last[:x_acceleration] = (2 * ((@log_by_robo[robot_scanned[:name]].last[:x] - @log_by_robo[robot_scanned[:name]][-2][:x]) - @log_by_robo[robot_scanned[:name]][-2][:x_speed] * t) / t ** 2 ).round
            @log_by_robo[robot_scanned[:name]].last[:x_acceleration] = round_whithin_range(@log_by_robo[robot_scanned[:name]].last[:x_acceleration], -1..1)
            @log_by_robo[robot_scanned[:name]].last[:y_acceleration] = (2 * ((@log_by_robo[robot_scanned[:name]].last[:y] - @log_by_robo[robot_scanned[:name]][-2][:y]) - @log_by_robo[robot_scanned[:name]][-2][:y_speed] * t) / t ** 2 ).round
            @log_by_robo[robot_scanned[:name]].last[:y_acceleration] = round_whithin_range(@log_by_robo[robot_scanned[:name]].last[:y_acceleration], -1..1)
            if @log_by_robo[robot_scanned[:name]].last[:heading] and @log_by_robo[robot_scanned[:name]][-2][:heading]
              @log_by_robo[robot_scanned[:name]].last[:angular_speed] = (@log_by_robo[robot_scanned[:name]].last[:heading] - @log_by_robo[robot_scanned[:name]][-2][:heading]) / t
              if  @log_by_robo[robot_scanned[:name]].last[:angular_speed].abs > 2
                @log_by_robo[robot_scanned[:name]].last[:radius] = (@log_by_robo[robot_scanned[:name]].last[:speed] / @log_by_robo[robot_scanned[:name]].last[:angular_speed].to_rad).abs.round
                @log_by_robo[robot_scanned[:name]].last[:angle_to_circle] = @log_by_robo[robot_scanned[:name]].last[:heading] - (@log_by_robo[robot_scanned[:name]].last[:angular_speed] > 0 ? 90 : 270 )
                @log_by_robo[robot_scanned[:name]].last[:angle_to_circle] += 360 if @log_by_robo[robot_scanned[:name]].last[:angle_to_circle] < 0
              end
            end
          end
        end
        if @log_by_robo[robot_scanned[:name]].size > 3
          @singular_points[robot_scanned[:name]] ||= []
          @singular_points[robot_scanned[:name]] << @log_by_robo[robot_scanned[:name]].select { |log|
            log[:x].round == @log_by_robo[robot_scanned[:name]].last[:x].round and log[:y].round == @log_by_robo[robot_scanned[:name]].last[:y].round and log[:x_speed]&.round == @log_by_robo[robot_scanned[:name]].last[:x_speed]&.round and log[:y_speed]&.round == @log_by_robo[robot_scanned[:name]].last[:y_speed]&.round and !(log[:x_speed].round == 0 and log[:y_speed].round == 0)
          }
        end
      end
      if num_robots > 2 and (55..59).cover? time % 60
        @turn_radar_direction = (0 < @turn_radar_direction ? 1 : -1) * MAX_ANGLE_OF_RADAR
      else
        diff_radar_direction = events['robot_scanned'].min_by { |log| log[:distance] }[:direction] - radar_heading
        @turn_radar_direction = optimize_angle(diff_radar_direction) * 2
        @adjust_radar = true
      end
    end
  end

  def set_run_params
    @turn_direction ||= 0
    @acceleration ||= 1
    @progress_direction ||= 1
    @gravity_points ||= {}
    @x_gravity = 0
    @y_gravity = 0
    return if @log_by_robo.empty?
    @recent_logs = @log_by_robo.map { |name, logs| (time - logs.last[:time]) < 6 ? logs.last : nil }.compact
    return if @recent_logs.empty?
    @recent_logs.each do |log|
      hit_bonus = 0
      next if log.size < 10
      got_hit = events['got_hit'].select { |hit_log| hit_log[:from] == log[:name] }.first
      hit_bonus = got_hit[:damage] * 2/3 if got_hit
      if (0.1..3).cover? @log_by_robo[log[:name]][-2][:energy] - log[:energy] + hit_bonus
        t = log[:distance] / BULLET_SPEED
        @gravity_points[time] = {
          x: x + speed * Math::cos(heading.to_rad) * t,
          y: y + speed * Math::sin(heading.to_rad) * t,
          power: 10,
          expire: time + t
        }
      end
    end
    @log_by_robo.each do |name, logs|
      @gravity_points[name] = {
        x: logs.last[:x],
        y: logs.last[:y],
        power: 10,
        expire: logs.last[:time] + 60
      }
    end
    if @size_of_bullet and @size_of_bullet < 0
      @gravity_points[@aim] = {
        x: @log_by_robo[@aim].last[:x],
        y: @log_by_robo[@aim].last[:y],
        power: -20,
        expire: time + 60
      }
    end
    @gravity_points[:top_wall] = {
        x: x,
        y: battlefield_height,
        power: 10,
        expire: time + 1
      }
    @gravity_points[:bottom_wall] = {
        x: x,
        y: 0,
        power: 10,
        expire: time + 1
      }
    @gravity_points[:left_wall] = {
        x: 0,
        y: battlefield_height - y,
        power: 10,
        expire: time + 1
      }
    @gravity_points[:right_wall] = {
        x: battlefield_width,
        y: battlefield_height - y,
        power: 10,
        expire: time + 1
      }
    @gravity_points.each do |name, gravity|
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
  end

  def set_attack_params
    @expected_hits ||= []
    @long_distance = false
    @singular_points.each do |name, singular_point|
      singular_point.each do |point|
        next if point.size < 3
        distance = Math::hypot(x - point.last[:x], (battlefield_height - y) - point.last[:y])
        time_to_be_hit = time + (distance / BULLET_SPEED)
        1.upto(point.size - 1) do |index|
          if (time_to_be_hit - (point[index][:time] * 2 - point[index - 1][:time])).abs < 2
            @turn_gun_direction = diff_direction( {x: x, y: battlefield_height - y}, {x: point.last[:x], y: point.last[:y]} ) - gun_heading
            @turn_gun_direction += (@turn_gun_direction * @turn_direction > 0 ? @turn_direction : -@turn_direction)
            @turn_gun_direction = optimize_angle @turn_gun_direction
            if @turn_gun_direction.abs <= 30
              @will_fire = true
              @aim = name
              return
            end
          end
        end
      end
    end
    target = @log_by_robo.map { |name, logs| time == logs.last[:time] ? logs.last : nil }.compact.min_by { |log| log[:distance] }
    return if !target or @log_by_robo[target[:name]].size < 4
    strategy = @attack_strategy.map { |strategy, score|
      {strategy: strategy, hit_ratio: (score[:hit] / score[:tries] * rand)}
    }.sort{ |a,b| b[:hit_ratio] - a[:hit_ratio]}.first[:strategy]
    direction = diff_direction( {x: target[:x], y: target[:y]}, {x: x, y: battlefield_height - y} )
    if strategy == :uniform_acceleration
      now_distance = Math::hypot(x - target[:x], (battlefield_height - y) - target[:y])
      x_run_away_point_after_tick = calc_spot(target[:x], target[:x_speed], target[:x_acceleration], 30)
      y_run_away_point_after_tick = calc_spot(target[:y], target[:y_speed], target[:y_acceleration], 30)
      run_away_by_tick = (now_distance - Math::hypot(x - x_run_away_point_after_tick, (battlefield_height - y) - y_run_away_point_after_tick)) / 30
      time_to_be_hit = target[:distance] / (BULLET_SPEED + run_away_by_tick)
      nextx = calc_spot(target[:x], target[:x_speed], target[:x_acceleration], time_to_be_hit)
      nexty = calc_spot(target[:y], target[:y_speed], target[:y_acceleration], time_to_be_hit)
    elsif strategy == :direct
      time_to_be_hit = target[:distance] / (BULLET_SPEED)
      nextx = target[:x]
      nexty = target[:y]
    end
    # elsif strategy == :right
    #   direction += 90
    #   direction -= 360 if direction > 360
    #   nextx = target[:x] + 240 * Math.cos(direction.to_rad)
    #   nexty = target[:y] - 240 * Math.sin(direction.to_rad)
    # elsif strategy == :left
    #   direction -= 90
    #   direction += 360 if direction < 0
    #   nextx = target[:x] + 240 * Math.cos(direction.to_rad)
    #   nexty = target[:y] - 240 * Math.sin(direction.to_rad)
    # end
    @turn_gun_direction = diff_direction( {x: x, y: battlefield_height - y}, {x: nextx, y: nexty} ) - gun_heading
    @turn_gun_direction -= @turn_direction
    @turn_gun_direction = optimize_angle @turn_gun_direction
    if @turn_gun_direction.abs <= 30 and gun_heat < 0.1
      @will_fire = true
      @long_distance = target[:distance] > 600
      @aim = target[:name]
      @attack_strategy[strategy][:tries] += 1
      @expected_hits << {time: time + time_to_be_hit, strategy: strategy}
    end
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

  def calc_spot(current_point, current_speed, current_acceleration, duration)
    result = current_point + (current_speed * duration)
    if current_acceleration.abs > 0
      acceleration_time = (current_speed * current_acceleration > 0 ? (8 - current_speed.abs)/current_acceleration.abs : (MAX_ROBO_SPEED + current_speed.abs)/current_acceleration.abs)
      result = current_point + (current_speed * acceleration_time) + (0.5 * current_acceleration * acceleration_time ** 2) + ( (0 < current_acceleration ? MAX_ROBO_SPEED : MIN_ROBO_SPEED ) * (duration - acceleration_time))
    end
    result
  end
end
