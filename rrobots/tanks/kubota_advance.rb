require "#{File.dirname(__FILE__)}/kubota"

class KubotaAdvance < Kubota
  PATTERN_LENGTH = 300.freeze
  PATTERN_CANDIDATES = 200.freeze
  PATTERN_OFFSET = 30.freeze

  def before_start
    super
    body_color 'red'
    radar_color 'red'
    turret_color 'red'
    font_color 'red'
    @debug_msg = false
    @debug_move = false
    @debug_defence = false
    @debug_attack = false
  end

  def game_over
    super
    @robots.each do |name, robot|
      log_by_aim_type = log_by_aim_type robot, 50000
      line = "#{name}: [ "
      log_by_aim_type.each do |aim_type, log|
        line += "#{aim_type}: #{log[:hit]} / #{log[:hit] + log[:miss]} (#{(log[:ratio] * 10000).to_i/100.0}%), "
      end
      debug line
    end
  end

  def tick events
    super events
  end

  private
  RANDOM_AVOIDANCE_ALPHA = -100.freeze
  RANDOM_AVOIDANCE_MULTI = 0.freeze

  def move_by_anti_gravity_enemy_bullets(vectors, bullet)
    if bullet[:unknown]
      vectors << anti_gravity(bullet[:unknown], battlefield_height + battlefield_width, RANDOM_AVOIDANCE_ALPHA, RANDOM_AVOIDANCE_MULTI)
    else
      super
    end
  end

  TEAM_BULLET_ACTION_TICK = 15.freeze
  TEAM_BULLET_AFFECT_DISTANCE = 200.freeze
  TEAM_BULLET_ALPHA = 100.freeze
  TEAM_BULLET_MULTI = 3.freeze
  def move_by_anti_gravity_team_bullets(vectors, bullet)
    move_by_anti_gravity_bullets vectors, bullet, TEAM_BULLET_ACTION_TICK, TEAM_BULLET_AFFECT_DISTANCE, TEAM_BULLET_ALPHA, TEAM_BULLET_MULTI
  end

  RAY_ACTION_TICK = 10.freeze
  RAY_ALPHA = 10.freeze
  RAY_MULTI = 0.freeze
  def move_by_anti_gravity_robots(vectors)
    teams.each do |robot|
      vectors << anti_gravity(robot[:prospect_point], TEAM_AFFECT_DISTANCE, TEAM_ALPHA, TEAM_MULTI)
      if @lockon_target
        diff_angle = angle_to_direction(robot[:direction] - @lockon_target[:direction])
        if diff_angle.abs > 120
          ray_direction = to_direction robot[:prospect_point], @lockon_target[:prospect_point]
          put_anti_gravity_point 0, @lockon_target[:prospect_point], battlefield_width + battlefield_height, CLOSING_ALPHA, CLOSING_MULTI
          RAY_ACTION_TICK.times.each do |index|
            ray_point = to_point ray_direction, (index-(RAY_ACTION_TICK/2))*BULLET_SPEED + robot[:distance], robot[:prospect_point]
            put_anti_gravity_point 0, ray_point, battlefield_width + battlefield_height, RAY_ALPHA, RAY_MULTI
          end
        end
      end
    end

    enemies.each do |robot|
      vectors << anti_gravity(robot[:prospect_point], ENEMY_AFFECT_DISTANCE, ENEMY_ALPHA, ENEMY_MULTI)
    end
  end

  def decide_move
    nearest = nil
    enemies.each do |e1|
      e1_distance = distance e1[:prospect_point], position
      enemies.each do |e2|
        next if e1 == e2
        point = to_point to_direction(e1[:prospect_point], e2[:prospect_point]), e1_distance, e1[:prospect_point]
        next if out_of_field?(point)
        p_distance = distance position, point
        if !nearest or nearest[:distance] > p_distance
          nearest = {
            distance: p_distance,
            point: point
          }
        end
      end
    end
    if nearest
      put_anti_gravity_point 0, nearest[:point], battlefield_height + battlefield_width, -5, 0
    end
    super
  end

  def prospect_next_by_pattern(robot)
    if @replay_point == nil
      diff_by_past = {}
      PATTERN_CANDIDATES.times.each do |d|
        diff_by_past[d] = {
          index: @lockon_target[:logs].length - (PATTERN_OFFSET + d) - 1,
          past: (PATTERN_OFFSET + d),
          diff: 0,
          count: 0,
          d: d
        }
      end
      candidate_count = PATTERN_CANDIDATES
      @lockon_target[:logs].reverse.first(PATTERN_LENGTH).each_with_index do |log, rindex|
        index_offset = @lockon_target[:logs].length - rindex - PATTERN_OFFSET - 1
        PATTERN_CANDIDATES.times.each do |d|
          diff_obj = diff_by_past[d]
          next unless diff_obj
          break if candidate_count <= 1
          past_log = @lockon_target[:logs][index_offset - d]
          unless past_log and past_log[:acceleration] and log[:acceleration]
            if rindex < 30
              diff_by_past[d] = nil
              candidate_count -= 1
            end
            break if past_log
            next
          end
          diff_by_past[d][:diff] += (log[:acceleration][:speed] - past_log[:acceleration][:speed]) ** 2
          diff_by_past[d][:diff] += diff_direction(log[:acceleration][:heading], past_log[:acceleration][:heading]) ** 2
          diff_by_past[d][:count] += 1
        end
        if rindex > (PATTERN_LENGTH / 6)
          sorted = diff_by_past.values.select{|a| a and a[:count] > 0}.sort{|a, b| (a[:diff] / a[:count]) <=> (b[:diff] / b[:count])}
          sorted.reverse.first((sorted.length * (0.5 - 0.5 * (PATTERN_LENGTH - rindex) / PATTERN_LENGTH)).to_i).each do |diff|
            diff_by_past[diff[:d]] = nil
            candidate_count -= 1
          end
        end
      end
      @replay_point = diff_by_past.values.compact.select{|a| a[:count] > 30}.min do |a, b|
        (a[:diff] / a[:count]) <=> (b[:diff] / b[:count])
      end
      @replay_point = false unless @replay_point
    end
    if @replay_point
      future_time = robot[:latest] - time + 1
      log = @lockon_target[:logs][@replay_point[:index] + future_time]
      log ||= @lockon_target[:logs][@replay_point[:index] + (future_time % @replay_point[:past])]
      if log
        ret = robot.dup
        ret[:acceleration] = log[:acceleration]
        return prospect_next_by_acceleration ret
      end
    else
      return prospect_next_by_acceleration robot
    end
  end

  def prospect_next_by_simple(robot)
    return prospect_next_by_acceleration(robot) if !robot[:statistics] or !robot[:acceleration]
    if @nearest == nil
      acceleration = {}
      robot[:statistics].each do |a|
        a[:s] = ((robot[:speed] - a[:speed]) ** 2) * 1.5 + ((robot[:distance] - a[:distance]) ** 2) + ((robot[:speed] - a[:acceleration][:speed]) ** 2) + ((robot[:acceleration][:heading] - a[:acceleration][:heading]) ** 2)
      end
      # @nearest = robot[:statistics].min do |a, b|
      #   a[:s] <=> b[:s]
      # end
      nearest_logs = robot[:statistics].sort{|a, b| a[:s] <=> b[:s]}.first(10)
      nearest_logs.each do |l1|
        l1[:s] = 0
        nearest_logs.each do |l2|
          if l1 != l2
            l1[:s] += (l1[:speed] - l2[:speed]) ** 2 + (l1[:heading] - l2[:heading]) ** 2
          end
        end
      end
      @nearest = nearest_logs.min {|a, b| a[:s] <=> b[:s]}
    end
    return prospect_next_by_acceleration(robot) unless @nearest

    diff_heading = diff_direction(@nearest[:prospect_heading], robot[:prospect_heading])
    target_future = {
      latest: robot[:latest],
      speed: @nearest[:speed],
      heading: (@nearest[:heading] - diff_heading),
      prospect_speed: @nearest[:speed],
      prospect_heading: (@nearest[:heading] - diff_heading),
      prospect_point: robot[:prospect_point],
      acceleration: { speed: 0, heading: 0 },
      logs: [],
    }

    return prospect_next_by_acceleration(target_future)
  end

  def aim_types
    # [:direct, :straight_12, :straight_24, :accelerated, :pattern, :simple]
    [:direct, :accelerated, :pattern, :simple]
  end

  def fire_with_logging_virtual_bullets(robot)
    super

    virtual_bullet robot, :pattern do |target_future|
      prospect_next_by_pattern target_future
    end

    virtual_bullet robot, :simple do |target_future|
      prospect_next_by_simple target_future
    end
  end

  def aim(power)
    aim_type = @lockon_target[:aim_type]
    aim_type = :direct if @lockon_target[:energy] <= ZOMBI_ENERGY
    if aim_type == :simple
      fire_or_turn power do |target_future|
        prospect_next_by_simple target_future
      end
      return aim_type
    else
      return if super(power)
      if aim_type == :pattern
        if @gun_heat > 0.2
          fire_or_turn power do |target_future|
            prospect_next_by_acceleration target_future
          end
        else
          fire_or_turn power do |target_future|
            prospect_next_by_pattern target_future
          end
        end
        return aim_type
      end
    end
    nil
  end

  RATIO_DENOMINATOR = 3.0.freeze
  UNKNOWN_MOVE_RATIO = 3.freeze
  def bullet_type_context(robot)
    current_context_by_bullet_type = {}
    full_context_by_bullet_type = {}
    hit_count = 0
    hit_count_unless_unknown = 0
    current_hit_time = 0
    robot[:got_hit_logs].reverse.each do |got_hit_log|
      bullet_type = got_hit_log[:bullet_type]
      if got_hit_log[:hit] > 0 and current_hit_time != got_hit_log[:time]
        current_hit_time = got_hit_log[:time]
        hit_count += 1.0
        hit_count_unless_unknown += 1.0 unless bullet_type == :unknown
      end
      full_context_by_bullet_type[bullet_type] ||= {bullet_type: bullet_type, hit: 0, total: 0, ratio: 0, type_ratio: 0}
      full_context_by_bullet_type[bullet_type][:hit] += got_hit_log[:hit]
      full_context_by_bullet_type[bullet_type][:total] += 1.0
      full_context_by_bullet_type[bullet_type][:ratio] = full_context_by_bullet_type[bullet_type][:hit] / full_context_by_bullet_type[bullet_type][:total]
      full_context_by_bullet_type[bullet_type][:type_ratio] = full_context_by_bullet_type[bullet_type][:hit] / hit_count_unless_unknown if hit_count_unless_unknown > 0
      next if hit_count > RATIO_DENOMINATOR
      current_context_by_bullet_type[bullet_type] ||= {bullet_type: bullet_type, hit: 0, total: 0, ratio: 0}
      current_context_by_bullet_type[bullet_type][:hit] += got_hit_log[:hit]
      current_context_by_bullet_type[bullet_type][:total] += 1.0
      current_context_by_bullet_type[bullet_type][:ratio] = current_context_by_bullet_type[bullet_type][:hit] / RATIO_DENOMINATOR
    end
    highest = current_context_by_bullet_type.values.max do |a, b|
      a[:ratio] <=> b[:ratio]
    end
    if highest and highest[:hit] >= 2 and highest[:ratio] >= 0.5 and \
      ((full_context_by_bullet_type[highest[:bullet_type]][:ratio] > 0.5 and full_context_by_bullet_type[highest[:bullet_type]][:type_ratio] > 0.5) or
       (robot[:num_fire] % UNKNOWN_MOVE_RATIO) != 0)
      return highest
    end
    {bullet_type: :unknown, hit: hit_count, total: hit_count}
  end

  def move_other_bullets_bullet_type(robot, bullet, bullet_type_context)
    if bullet_type_context[:bullet_type] == :unknown
      if @lockon_target == robot
        robot[:unknown_bullet] = bullet if !robot[:unknown_bullet] or !robot[:unknown_bullet][:unknown]
      else
        bullet_type_context[:bullet_type] = :direct
        super(robot, bullet, bullet_type_context)
      end
    else
      super(robot, bullet, bullet_type_context)
    end
  end

  def random_by_slope(slope)
    random = 0
    count = slope
    while count > 0
      count -= 1.0
      alpha = 1.0
      if count < 0
        alpha = count + 1.0
      end
      random += alpha * SecureRandom.random_number
    end
    1 - (random * 2.0 / slope - 1).abs
  end

  def move_enemy_bullets
    super
    # TODO: move to where ?
    @robots.each do |name, robot|
      if robot[:unknown_bullet] and !robot[:unknown_bullet][:unknown]
        bullet = robot[:unknown_bullet]
        distance_to_bullet = distance(bullet[:point], position)
        landing_ticks = distance_to_bullet / BULLET_SPEED
        bullet_direction = to_direction(position, bullet[:start])
        move_direction = (bullet_direction + 90) % 360
        if landing_ticks < 10
          ticks = 15
        else
          slope = 1 + (50.0 / landing_ticks)
          random = random_by_slope slope
          ticks = (landing_ticks * random).to_i
          # TODO limit ticks to avoid long run
        end
        diff_turn = diff_direction(move_direction, heading)
        patterns = [
          {
            turn: diff_turn,
            heading: heading,
            speed: speed,
            acceleration: 1,
            point: position,
          }, {
            turn: angle_to_direction(diff_turn + 180),
            heading: heading,
            speed: speed,
            acceleration: 1,
            point: position,
          }, {
            turn: diff_turn,
            heading: heading,
            speed: speed,
            acceleration: -1,
            point: position,
          }, {
            turn: angle_to_direction(diff_turn + 180),
            heading: heading,
            speed: speed,
            acceleration: -1,
            point: position,
          }]
        for pattern in patterns
          ticks.times do |i|
            current_turn = max_turn pattern[:turn], MAX_TURN
            pattern[:turn] -= current_turn
            pattern[:heading] += current_turn
            pattern[:speed] = next_speed(pattern[:speed], pattern[:acceleration])
            pattern[:point] = eval_wall to_point(pattern[:heading], pattern[:speed], pattern[:point])
          end
        end
        if SecureRandom.random_number < 0.5
          pattern = patterns.max{|pattern|
            Math.cos(to_radian(diff_direction(move_direction, to_direction(position, pattern[:point])))) * distance(position, pattern[:point])
          }
          bullet[:unknown] = pattern[:point]
        else
          pattern = patterns.min{|pattern|
            Math.cos(to_radian(diff_direction(move_direction, to_direction(position, pattern[:point])))) * distance(position, pattern[:point])
          }
          bullet[:unknown] = pattern[:point]
        end
      end
    end
  end

  def set_lockon_mode(name = nil)
    if name
      super name
    else
      target = nil
      enemies.select{|enemy| enemy[:zombi_tick] < time }.each do |a|
        a[:tmp][:lockon_distance] = 0
        def adjust_distance(distance, bot)
          result = 0
          if distance < TOTALLY_HIT_DISTANCE
            result = 1
          elsif distance < SAFETY_DISTANCE
            result = 2
          else
            result = distance
          end
          if !bot
            result *= 3
          end
          result
        end
        teams.each do |team_member|
          member_name = team_member[:name]
          member = @robots[member_name]
          adusted_distance = adjust_distance distance(member[:prospect_point], a[:prospect_point]), member[:bot]
          if adusted_distance < @size
            a[:tmp][:lockon_distance] = [a[:tmp][:lockon_distance], adusted_distance].min
          elsif a[:tmp][:lockon_distance] == 0 or a[:tmp][:lockon_distance] > @size
            a[:tmp][:lockon_distance] += adusted_distance
          end
        end
        adusted_distance = adjust_distance a[:distance], self.class::BOT
        if adusted_distance < @size
          a[:tmp][:lockon_distance] = [a[:tmp][:lockon_distance], adusted_distance].min
        elsif a[:tmp][:lockon_distance] == 0 or a[:tmp][:lockon_distance] > @size
          a[:tmp][:lockon_distance] += adusted_distance
        end
        if a[:energy] < ZOMBI_ENERGY
          a[:tmp][:lockon_distance] = 0
        # else
        #   a[:tmp][:lockon_distance] *= (a[:energy] ** 0.5)
        end
      end
      target = enemies.select{|enemy| enemy[:zombi_tick] < time }.sort{|a, b|
        a[:tmp][:lockon_distance] <=> b[:tmp][:lockon_distance]
      }.first
      if target
        super target[:name]
      else
        super
      end
    end
  end

  def initial
    super
  end

  COLORS = ['white', 'blue', 'yellow', 'red', 'lime'].freeze
  def initial_for_tick events
    super
    color = COLORS[(time / 5) % COLORS.size]
    body_color color
    radar_color color
    turret_color color
    font_color color

    @replay_point = nil
    @nearest = nil
    @robots.values.each do |robot|
      robot[:unknown_bullet] = nil
    end
  end
end
