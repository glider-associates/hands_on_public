require 'securerandom'

module SampleUtil
  ON_THE_WALL = 3
  def accelerate_with_random(n, with_random)
    if with_random and SecureRandom.random_number < 0.2
      accelerate -n
    else
      accelerate n
    end
  end

  def move_to_coner(angle, with_random, &distance_from_wall)
    @turn_angle = 0
    if heading == angle
      accelerate_with_random 1, with_random
      distance = distance_from_wall.call
      if distance <= ON_THE_WALL
        accelerate -speed
      elsif distance < 49 and speed != 0
        accelerate 0
        if distance < (speed * (1 + (speed - 1) / 2) + 8.0)
          accelerate -1
        end
        if speed <= 1 and distance > 2
          accelerate 0
        end
      end
    else
      accelerate -speed
      @turn_angle = (angle - heading + 360) % 360
      @turn_angle -= 360 if @turn_angle > 180
      turn @turn_angle
    end
  end

  def wall_move(with_random = false)
    if x <= @size + ON_THE_WALL and y <= @size + ON_THE_WALL
      move_to_coner 0, with_random do
        battlefield_width - @size - x
      end
    elsif y <= @size + ON_THE_WALL and x >= battlefield_width - @size - ON_THE_WALL
      move_to_coner 270, with_random do
        battlefield_height - @size - y
      end
    elsif y >= battlefield_height - @size - ON_THE_WALL and x <= @size + ON_THE_WALL
      move_to_coner 90, with_random do
        y - @size
      end
    elsif y >= battlefield_height - @size - ON_THE_WALL and x >= battlefield_width - @size - ON_THE_WALL
      move_to_coner 180, with_random do
        x - @size
      end
    elsif y <= @size + ON_THE_WALL
      move_to_coner 0, with_random do
        battlefield_width - @size - x
      end
    elsif x >= battlefield_width - @size - ON_THE_WALL
      move_to_coner 270, with_random do
        battlefield_height - @size - y
      end
    elsif y >= battlefield_height - @size - ON_THE_WALL
      move_to_coner 180, with_random do
        x - @size
      end
    else
      move_to_coner 90, with_random do
        y - @size
      end
    end
  end

  def quick_shoot
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

  def scan_for_fire
    @scan_time ||= 0
    @scanned_by_name ||= {}
    @turn_radar_angle ||= 60
    if @scan_time == time
      return @nearest
    end
    @scan_time = time
    events['robot_scanned'].each{|scanned|
      @scanned_by_name[scanned[:name]] ||= {}
      @scanned_by_name[scanned[:name]][:latest] = time
      @scanned_by_name[scanned[:name]][:name] = scanned[:name]
      @scanned_by_name[scanned[:name]][:direction] = scanned[:direction]
      @scanned_by_name[scanned[:name]][:distance] = scanned[:distance]
      @scanned_by_name[scanned[:name]][:energy] = scanned[:energy]
    }
    @scanned_by_name.each do |name, scanned|
      next unless scanned
      @scanned_by_name[name] = nil if (time - scanned[:latest]) > 10
      diff = (scanned[:direction] - gun_heading) % 360
      diff -= 360 if diff > 180
      diff += 360 if diff < -180
      scanned[:diff] = diff
    end

    @nearest = @scanned_by_name.values.compact.reject{|robot| team_members.include? robot[:name]}.min do |a, b|
      a[:diff] <=> b[:diff]
    end

    if @nearest and @nearest[:latest] == time
      @turn_radar_angle *= -1
    end
    turn_radar @turn_radar_angle

    @nearest
  end

  def advanced_shoot(power, &block)
    if @will_fire
      fire power
      @will_fire = false
    end
    nearest = scan_for_fire
    if nearest
      if nearest[:latest] == time
        radian = (nearest[:direction] / 180.0 * Math::PI)
        point = {
          x: Math.cos(radian) * nearest[:distance] + x,
          y: -Math.sin(radian) * nearest[:distance] + y
        }
        ticks = (nearest[:distance] / 30) - 1
        if nearest[:point] and gun_heat <= 0.1
          block.call nearest, ticks, point
        end
        nearest[:point] = point
      end
      @last_nearest = nearest[:latest]
    end
  end

  def shoot_uniform_speed(power = 3)
    advanced_shoot power do |nearest, ticks, point|
      nx = (point[:x] - nearest[:point][:x]) / (time - @last_nearest) * ticks + point[:x]
      ny = (point[:y] - nearest[:point][:y]) / (time - @last_nearest) * ticks + point[:y]
      nangle = ((Math.atan2((ny - y), (x - nx)) - Math::PI) * 180.0 / Math::PI + 360) % 360
      diff = (nangle - gun_heading) % 360
      diff -= 360 if diff > 180
      diff += 360 if diff < -180
      @turn_angle = [[@turn_angle, 10].min, -10].max
      turn_gun (diff - @turn_angle)
      if (diff - @turn_angle).abs <= 30
        @will_fire = true
      end
    end
  end
end
