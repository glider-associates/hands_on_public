require 'rrobots'
class Watanabe
  include Robot

  MAX_RADAR_TURN         = 60
  MAX_GUN_TURN           = 30
  MAX_TURN               = 10
  DANGER_POINT_THRESHOLD = 200
  BULLET_SPPED           = 30
  BULLET_MULTIPLICATIOS  = 3.3
  SAFETY_DISTANCE        = 300

  def initialize
    @aim_logs = {}
    @target_info = {}
    @target = nil
    @accelerate_value = 1
    @pattern = nil
    @ramdom_pattern = false
    @turn_radar_value = MAX_RADAR_TURN
    @turn_value = 0
    @fire_value = 0
    @will_fire = false
    @summary_pattern = { straight: 0, turn_back: 0, direct: 0 }
  end

  def reset
  end

  def present_point
    { x: x, y: y }
  end

  def future_point
    calc_point(present_point, speed + @accelerate_value, heading + @turn_value)
  end

  def calc_point(base_point, distance, direction)
    {
      x: base_point[:x] + (Math::cos(direction.to_rad) * distance),
      y: base_point[:y] + (- Math::sin(direction.to_rad) * distance)
    }
  end

  def calc_distance(a, b)
    Math.hypot(a[:x] - b[:x], a[:y] - b[:y])
  end

  def center_point_of_circle
    x1 = @target_info[@target][-3][:point][:x]
    x2 = @target_info[@target][-2][:point][:x]
    x3 = @target_info[@target][-1][:point][:x]
    y1 = @target_info[@target][-3][:point][:y]
    y2 = @target_info[@target][-2][:point][:y]
    y3 = @target_info[@target][-1][:point][:y]
    d = (y2*x1 - y1*x2 + y3*x2 - y2*x3 + y1*x3 - y3*x1);
    x = ((x1*x1 + y1*y1) * (y2-y3) + (x2*x2 + y2*y2) * (y3-y1) + (x3*x3 + y3*y3) * (y1-y2)) / (2*d);
    y = -((x1*x1 + y1*y1) * (x2-x3) + (x2*x2 + y2*y2) * (x3-x1) + (x3*x3+y3*y3) * (x1-x2)) / (2*d);

    if x.finite? || y.finite?
      {x: x, y: y}
    else
      nil
    end
  end

  def diff_energy
    @target_info[@target][-2][:energy] - @target_info[@target].last[:energy]
  end

  def to_degree(radian)
    (radian * 180.0 / Math::PI + 360) % 360
  end

  def angle(a, b)
    to_degree(Math::atan2(b[:y] - a[:y], a[:x] - b[:x]) - Math::PI)
  end

  def adjust_direction(angle)
    angle = angle % 360
    if angle > 180
      angle -= 360
    elsif angle < -180
      angle += 360
    end
    angle
  end

  def was_shot?
    return false if @target_info[@target].size <= 2
    0 < diff_energy && diff_energy <= 3
  end

  def center_direction
    angle({x: battlefield_width / 2, y: battlefield_height / 2}, {x: x, y: y})
  end

  def dangerous_area?
    x < DANGER_POINT_THRESHOLD || x > (battlefield_width - DANGER_POINT_THRESHOLD) || y < DANGER_POINT_THRESHOLD || y > (battlefield_height - DANGER_POINT_THRESHOLD)
  end

  def got_hit_logs
    @aim_logs[@target].select{|log| log[:got_hit] }.last(30).reverse
  end

  def summary_pattern
    score = 30
    got_hit_logs.each do |log|
      @summary_pattern[log[:pattern]] += score
      score -= 1
    end
    @summary_pattern.max{|a, b| a[1] <=> b[1] }[0]
  end

  def decide_pattern
    if @target_info[@target].size >= 5 && @target_info[@target].last(3).select{
        |info| !info[:center_point_of_circle].nil? && !@target_info[@target].last[:center_point_of_circle].nil? && info[:center_point_of_circle][:x].round == @target_info[@target].last[:center_point_of_circle][:x].round && info[:center_point_of_circle][:y].round == @target_info[@target].last[:center_point_of_circle][:y].round }.size > 2
      @pattern = :circle
    else
      @pattern = :straight
    end
  end

  def search_target
    unless events['robot_scanned'].empty?
      events['robot_scanned'].each do |robot_scanned|
        @target_info[robot_scanned[:name]] ||= []
        @target_info[robot_scanned[:name]] << robot_scanned
        @target_info[robot_scanned[:name]].last[:time] = time
        @target_info[robot_scanned[:name]].last[:point] = calc_point(present_point, @target_info[robot_scanned[:name]].last[:distance], @target_info[robot_scanned[:name]].last[:direction])

        if @target_info[robot_scanned[:name]].size >= 2
          t = @target_info[robot_scanned[:name]].last[:time] - @target_info[robot_scanned[:name]][-2][:time]
          @target_info[robot_scanned[:name]].last[:x_velocity] = (@target_info[robot_scanned[:name]].last[:point][:x] - @target_info[robot_scanned[:name]][-2][:point][:x]) / t
          @target_info[robot_scanned[:name]].last[:y_velocity] = (@target_info[robot_scanned[:name]].last[:point][:y] - @target_info[robot_scanned[:name]][-2][:point][:y]) / t
          @target_info[robot_scanned[:name]].last[:velocity]   = calc_distance(@target_info[robot_scanned[:name]][-2][:point], @target_info[robot_scanned[:name]].last[:point]) / t
          @target_info[robot_scanned[:name]].last[:heading]    = angle(@target_info[robot_scanned[:name]][-2][:point], @target_info[robot_scanned[:name]].last[:point])

          if @target_info[robot_scanned[:name]].size >= 3
            @target_info[robot_scanned[:name]].last[:x_acceleration] = @target_info[robot_scanned[:name]][-2][:x_velocity] - @target_info[robot_scanned[:name]].last[:x_velocity] / t
            @target_info[robot_scanned[:name]].last[:y_acceleration] = @target_info[robot_scanned[:name]][-2][:y_velocity] - @target_info[robot_scanned[:name]].last[:y_velocity] / t
            @target_info[robot_scanned[:name]].last[:acceleration] = (@target_info[robot_scanned[:name]].last[:velocity] - @target_info[robot_scanned[:name]][-2][:velocity]) / t
            @target_info[robot_scanned[:name]].last[:angle_velocity] = adjust_direction(@target_info[robot_scanned[:name]].last[:heading] - @target_info[robot_scanned[:name]][-2][:heading]) / t
            @target_info[robot_scanned[:name]].last[:center_point_of_circle] = center_point_of_circle
            @target_info[robot_scanned[:name]].last[:radius] = calc_distance(@target_info[robot_scanned[:name]].last[:point], @target_info[robot_scanned[:name]].last[:center_point_of_circle]) unless @target_info[robot_scanned[:name]].last[:center_point_of_circle].nil?
          end
        end
      end

      @turn_radar_value *= -1
    end
    turn_radar @turn_radar_value
  end

  def set_hit_log
    unless events['got_hit'].empty?
      events['got_hit'].each do |event|
        fire_value = event[:damage] / BULLET_MULTIPLICATIOS
        index = @aim_logs[event[:from]].reverse.index{|log| log[:fire_value] == fire_value }
        @aim_logs[event[:from]].reverse[index].merge!(got_hit: true) unless index.nil?
      end
    end
  end

  def set_target
    unless @target_info.empty?
      @target_info.each do |robot_name, infos|
        if @target.nil? || @target_info[@target].last[:distance] > @target_info[robot_name].last[:distance]
          @target = robot_name
        end
      end
    end
  end

  def move
    unless @target_info[@target].nil?
      if was_shot?
        if SecureRandom.random_number < 0.3
          @accelerate_value *= -1
        elsif SecureRandom.random_number < 0.6
          @accelerate_value = [-0.7, -0.5, -0.3, 0.3, 0.5, 0.7].sample
        end
      end
      @turn_value = adjust_direction(@target_info[@target].last[:direction] - heading) + 90
    end
  end

  def target_future_point
    point, diff_angle = [nil, 0]
    (1..30).each do |tick|
      point = case @pattern
              when :circle
                calc_point(@target_info[@target].last[:center_point_of_circle], @target_info[@target].last[:radius], adjust_direction(@target_info[@target].last[:angle_velocity] * tick + (@target_info[@target].last[:heading]) - 90))
              when :straight
                { x: @target_info[@target].last[:point][:x] + @target_info[@target].last[:x_velocity] * tick, y: @target_info[@target].last[:point][:y] + @target_info[@target].last[:y_velocity] * tick }
              when :turn_back
                { x: @target_info[@target].last[:point][:x] - (@target_info[@target].last[:x_velocity] * tick), y: @target_info[@target].last[:point][:y] - (@target_info[@target].last[:y_velocity] * tick) }
              when :direct
                @target_info[@target].last[:point]
              end

      diff_angle = adjust_direction(angle(present_point, point) - gun_heading)
      diff_angle -= @turn_value
      distance = calc_distance(point, present_point)
      break if diff_angle.abs < MAX_GUN_TURN && distance - (BULLET_SPPED * tick) < 10
    end
    [point, diff_angle]
  end

  def set_aim
    return turn_gun MAX_GUN_TURN if @target_info.empty?
    return if @target_info[@target].size < 3
    decide_pattern
    point, diff_angle = target_future_point

    turn_gun diff_angle
    @will_fire = true if gun_heat == 0 && !point.nil?
  end

  def attack
    if !@target_info.empty? && @target_info[@target].last[:energy] < 0.5
      @accelerate_value = 1
      diff_direction = angle(present_point, @target_info[@target].last[:point]) - heading
      @turn_value = adjust_direction(diff_direction)
      @will_fire = false
    end

    if @will_fire
      @fire_value = if @target_info[@target].last[:distance] < 500
                      3
                    elsif @target_info[@target].last[:distance] > 500 && @target_info[@target].last[:distance] < 1000
                      2
                    else
                      0.3
                    end
      @aim_logs[@target] ||= []
      @aim_logs[@target] << { pattern: @pattern, fire_value: @fire_value, time: time }

      @will_fire = false
    end
  end

  def tick(events)
    return if num_robots == 1
    reset
    # set_hit_log
    search_target
    set_target
    set_aim
    move
    attack
    fire @fire_value
    turn @turn_value
    accelerate @accelerate_value
  end
end
