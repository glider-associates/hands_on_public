require 'rrobots'
require 'matrix'
require 'logger'

class Yamaguchi
  include Robot

  BULLET_SPEED = 30
  MAX_ANGLE_OF_RADAR = 60
  MAX_ANGLE_OF_GUN = 30
  MAX_ROBO_SPEED = 8
  MIN_ROBO_SPEED = -8

  def initialize
    @correct_strategy = :direct
    @logg = Logger.new(STDOUT)
  end

  def tick(events)
    @got_hit_log = {} if time == 0
    @log_by_robo = {} if time == 0
    @targets = [] if time == 0
    if @will_fire and num_robots > 1
      @pre_fire = true
      @will_fire = false
      @size_of_bullet = (@log_by_robo[@aim].last[:energy] > 20 ? 3 : @log_by_robo[@aim].last[:energy]/3.3 - 0.3)
      @size_of_bullet = (@log_by_robo[@aim].last[:energy] > 20 ? 1 : @log_by_robo[@aim].last[:energy]/3.3 - 0.3) if @long_distance
      @size_of_bullet = 3 if @short_distance
      fire @size_of_bullet if @log_by_robo[@aim].last[:energy] >= 0.5
    end
    get_enemies_info
    set_run_params
    @turn_direction = round_whithin_range @turn_direction, -10..10
    set_attack_params
    @turn_gun_direction = round_whithin_range @turn_gun_direction, -30..30
    turn @turn_direction
    turn_gun @turn_gun_direction
    if @adjust_radar
      diff_radar_direction = events['robot_scanned'].min_by { |log| log[:distance] }[:direction] - radar_heading
      @turn_radar_direction = optimize_angle(diff_radar_direction) * 2
      @turn_radar_direction -= (@turn_direction + @turn_gun_direction)
      @adjust_radar = false
    end
    turn_radar optimize_angle(@turn_radar_direction)
    accelerate @acceleration
  end

  def get_enemies_info
    @turn_radar_direction ||= MAX_ANGLE_OF_GUN
    @turn_gun_direction ||= 0
    unless events['got_hit'].empty?
      @got_hit_log[events['got_hit'].first[:from]] ||= []
      @got_hit_log[events['got_hit'].first[:from]].delete_if { |hit_time| time - hit_time > 60 }
      @got_hit_log[events['got_hit'].first[:from]] << time
      @emergency = @got_hit_log[events['got_hit'].first[:from]].size > 1
      @avoid_angle *= -1 if rand < 0.8
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
            next if log == @log_by_robo[robot_scanned[:name]].last
            log[:x].round == @log_by_robo[robot_scanned[:name]].last[:x].round and log[:y].round == @log_by_robo[robot_scanned[:name]].last[:y].round and log[:x_speed]&.round == @log_by_robo[robot_scanned[:name]].last[:x_speed]&.round and log[:y_speed]&.round == @log_by_robo[robot_scanned[:name]].last[:y_speed]&.round and !(log[:x_speed].round == 0 and log[:y_speed].round == 0)
          }
        end
      end
      if num_robots > 2 and (55..59).cover? time % 60
        @turn_radar_direction = (0 < @turn_radar_direction ? 1 : -1) * MAX_ANGLE_OF_RADAR
      else
        @adjust_radar = true
      end
    end
    if @expected_hits and !@expected_hits.empty? and @expected_hits.last[:time].round == time.round
      @correct_strategy =  @expected_hits.last[:points].min { |a, b|
        Math::hypot(a[1][:x] - @log_by_robo[@expected_hits.last[:name]].last[:x], a[1][:y] - @log_by_robo[@expected_hits.last[:name]].last[:y]) <=> Math::hypot(b[1][:x] - @log_by_robo[@expected_hits.last[:name]].last[:x], b[1][:y] - @log_by_robo[@expected_hits.last[:name]].last[:y])
      }.first
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
      @target_angle = diff_direction({x: x, y: (battlefield_height - y)}, {x: log[:x], y: log[:y]})
      diff_energy = @log_by_robo[log[:name]][-2][:energy] - log[:energy] + hit_bonus
      if (0.1..3).cover? diff_energy
        @avoid_angle *= -1 if diff_energy > 2 and rand < 0.8
        t = log[:distance] / BULLET_SPEED
        @gravity_points[time] = {
          x: x + speed * Math::cos(heading.to_rad) * t,
          y: y - speed * Math::sin(heading.to_rad) * t,
          power: 5,
          expire: time + t
        }
      end
    end
    @log_by_robo.each do |name, logs|
      @gravity_points[name] = {
        x: logs.last[:x],
        y: logs.last[:y],
        power: 15,
        expire: logs.last[:time] + 60
      }
    end

    @avoid_angle ||= 90
    @avoid_angle *= -1 if rand < 0.05
    if @target_angle
      @gravity_points['randam'] = {
        x: x + 100 * Math::cos((optimize_angle(@target_angle + @avoid_angle)).to_rad),
        y: (battlefield_height - y) + 100 * Math::sin((optimize_angle(@target_angle + @avoid_angle)).to_rad),
        power: 5,
        expire: time + 30
      }
    end

    if @log_by_robo[@aim] and @log_by_robo[@aim].last[:energy].to_f < 1
      @gravity_points[@aim] = {
        x: @log_by_robo[@aim].last[:x],
        y: @log_by_robo[@aim].last[:y],
        power: -100,
        expire: time + 1000
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
    @short_distance = false
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
    direction = diff_direction( {x: target[:x], y: target[:y]}, {x: x, y: battlefield_height - y} )

    # :uniform_acceleration
    now_distance = Math::hypot(x - target[:x], (battlefield_height - y) - target[:y])
    x_run_away_point_after_tick = calc_spot(target[:x], target[:x_speed], target[:x_acceleration], 30)
    y_run_away_point_after_tick = calc_spot(target[:y], target[:y_speed], target[:y_acceleration], 30)
    run_away_by_tick = (now_distance - Math::hypot(x - x_run_away_point_after_tick, (battlefield_height - y) - y_run_away_point_after_tick)) / 30
    time_to_be_hit = target[:distance] / (BULLET_SPEED + run_away_by_tick)
    nextx_uniform_acceleration = calc_spot(target[:x], target[:x_speed], target[:x_acceleration], time_to_be_hit)
    nexty_uniform_acceleration = calc_spot(target[:y], target[:y_speed], target[:y_acceleration], time_to_be_hit)

    # :direct
    nextx_direct = target[:x]
    nexty_direct = target[:y]

    # :right
    angle = direction + 90
    angle -= 360 if angle > 360
    nextx_right = target[:x] + 30 * Math.cos(angle.to_rad)
    nexty_right = target[:y] + 30 * Math.sin(angle.to_rad)

    # :right2
    nextx_right2 = target[:x] + 70 * Math.cos(angle.to_rad)
    nexty_right2 = target[:y] + 70 * Math.sin(angle.to_rad)

    # :right3
    nextx_right3 = target[:x] + 110 * Math.cos(angle.to_rad)
    nexty_right3 = target[:y] + 110 * Math.sin(angle.to_rad)

    # :right4
    nextx_right4 = target[:x] + 150 * Math.cos(angle.to_rad)
    nexty_right4 = target[:y] + 150 * Math.sin(angle.to_rad)

    # :left
    angle = direction - 90
    angle += 360 if angle < 0
    nextx_left = target[:x] + 30 * Math.cos(angle.to_rad)
    nexty_left = target[:y] + 30 * Math.sin(angle.to_rad)

    # :left2
    nextx_left2 = target[:x] + 70 * Math.cos(angle.to_rad)
    nexty_left2 = target[:y] + 70 * Math.sin(angle.to_rad)

    # :left3
    nextx_left3 = target[:x] + 110 * Math.cos(angle.to_rad)
    nexty_left3 = target[:y] + 110 * Math.sin(angle.to_rad)

    # :left4
    nextx_left4 = target[:x] + 150 * Math.cos(angle.to_rad)
    nexty_left4 = target[:y] + 150 * Math.sin(angle.to_rad)

    strategy = @correct_strategy
    strategy = :uniform_acceleration if target[:distance] < 500
    if target[:distance] < 300
      strategy = :direct
      @short_distance = true
    end
    if strategy == :uniform_acceleration
      nextx = nextx_uniform_acceleration
      nexty = nexty_uniform_acceleration
    elsif strategy == :right
      nextx = nextx_right
      nexty = nexty_right
    elsif strategy == :right2
      nextx = nextx_right2
      nexty = nexty_right2
    elsif strategy == :right3
      nextx = nextx_right3
      nexty = nexty_right3
    elsif strategy == :right4
      nextx = nextx_right4
      nexty = nexty_right4
    elsif strategy == :left
      nextx = nextx_left
      nexty = nexty_left
    elsif strategy == :left2
      nextx = nextx_left2
      nexty = nexty_left2
    elsif strategy == :left3
      nextx = nextx_left3
      nexty = nexty_left3
    elsif strategy == :left4
      nextx = nextx_left4
      nexty = nexty_left4
    end
    if strategy == :direct or nextx < 0 or nextx > battlefield_width or nexty < 0 or nexty > battlefield_height
      strategy = :direct
      nextx = nextx_direct
      nexty = nexty_direct
    end

    time_to_be_hit = Math::hypot(target[:x] - y, target[:y] - (battlefield_height - y)) / (BULLET_SPEED)

    @turn_gun_direction = diff_direction( {x: x, y: battlefield_height - y}, {x: nextx, y: nexty} ) - gun_heading
    @turn_gun_direction -= @turn_direction
    @turn_gun_direction = optimize_angle @turn_gun_direction
    if @turn_gun_direction.abs <= 30 and gun_heat < 0.1 and !@pre_fire
      @will_fire = true
      @long_distance = target[:distance] > 1000
      @aim = target[:name]
      @expected_hits << {
        time: time + time_to_be_hit,
        strategy: strategy,
        name: target[:name],
        points: {
          uniform_acceleration: {x: nextx_uniform_acceleration, y: nexty_uniform_acceleration},
          direct: {x: nextx_direct, y: nexty_direct},
          right: {x: nextx_right, y: nexty_right},
          left: {x: nextx_left, y: nexty_left},
          right2: {x: nextx_right2, y: nexty_right2},
          left2: {x: nextx_left2, y: nexty_left2},
          right3: {x: nextx_right3, y: nexty_right3},
          left3: {x: nextx_left3, y: nexty_left3},
          right4: {x: nextx_right4, y: nexty_right4},
          left4: {x: nextx_left4, y: nexty_left4},
        }
      }
    end
    @pre_fire = false
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
