require 'securerandom'

class RobotRunner
  include Coordinate

  STATE_IVARS = [ :x, :y, :gun_heat, :heading, :gun_heading, :radar_heading, :time, :size, :speed, :energy ]
  NUMERIC_ACTIONS = [ :fire, :turn, :turn_gun, :turn_radar, :accelerate]
  STRING_ACTIONS = [ :say, :broadcast, :team_message ]
  STYLES = [ :font_color, :body_color, :turret_color, :radar_color ]

  STATE_IVARS.each{|iv|
    attr_accessor iv
  }
  NUMERIC_ACTIONS.each{|iv|
    attr_accessor "#{iv}_min", "#{iv}_max"
  }
  STRING_ACTIONS.each{|iv|
    attr_accessor "#{iv}_max"
  }

  STYLES.each{|iv|
    define_method(iv){|| @robot.styles[iv] }
  }

  attr_accessor :uniq_name
  #AI of this robot
  attr_accessor :robot

  #team of this robot
  attr_accessor :team
  attr_accessor :team_members

  #keeps track of total damage done by this robot
  attr_accessor :damage_given
  attr_accessor :friend_damage_given
  attr_accessor :damage_taken
  attr_accessor :bullet_damage_given
  attr_accessor :friend_bullet_damage_given
  attr_accessor :bullet_damage_taken
  attr_accessor :ram_damage_given
  attr_accessor :friend_ram_damage_given
  attr_accessor :ram_damage_taken
  attr_accessor :ram_kills
  attr_accessor :friend_ram_kills

  #keeps track of the kills
  attr_accessor :kills
  attr_accessor :friend_kills

  attr_reader :actions, :speech

  attr_accessor :events
  attr_accessor :prev_x
  attr_accessor :prev_y
  attr_accessor :prev_speed
  attr_accessor :num_fire
  attr_accessor :num_hit

  def initialize robot, bf, team, uniq_name, options
    @robot = robot
    @battlefield = bf
    @team = team
    @team_members = []
    @uniq_name = uniq_name
    set_action_limits
    set_initial_state
    @events = Hash.new{|h, k| h[k]=[]}
    @actions = Hash.new(0)
    @robot.styles = Hash.new(0)
    @num_fire = 0
    @num_hit = 0
    if robot.class::BOT
      @bot = true
      @energy *= 1.5
    end
    @leader = false if options.teams.length > 0
  end

  def before_start
    @robot.name = @uniq_name
    @robot.team_members = @team_members.map(&:uniq_name)
    @robot.before_start if @robot.respond_to? :before_start
    if @robot.team_members.first == uniq_name and @leader == false
      @leader = true
      @energy *= 2
    end
    if @leader == true
      teleport
    else
      leader = @battlefield.robots.select {|robot|
        robot.uniq_name == @robot.team_members.first
      }.first
      @x = leader.x
      @y = leader.y
      teleport (@battlefield.width/3)-@size*2, (@battlefield.height/3)-@size*2, @size*2
    end
  end

  def skin_prefix
    @robot.skin_prefix
  end

  def set_initial_state
    @x = @battlefield.width / 2
    @y = @battlefield.height / 2
    @prev_x = @x
    @prev_y = @y
    @speech_counter = -1
    @speech = nil
    @time = 0
    @size = 60
    @speed = 0
    @energy = 100
    @kills = 0
    @friend_kills = 0
    @damage_given = 0
    @friend_damage_given = 0
    @damage_taken = 0
    @bullet_damage_given = 0
    @friend_bullet_damage_given = 0
    @bullet_damage_taken = 0
    @ram_damage_given = 0
    @friend_ram_damage_given = 0
    @ram_damage_taken = 0
    @ram_kills = 0
    @friend_ram_kills = 0
  end

  def random_axis(current, distance)
    min_axis_distance=(((@size * 2) ** 2) / 2) ** 0.5 + 1
    diff = SecureRandom.random_number * (distance - min_axis_distance) + min_axis_distance
    if SecureRandom.random_number < 0.5
      current - diff
    else
      current + diff
    end
  end

  N_TRY = 100.freeze
  def teleport(distance_x=(@battlefield.width/2)-@size*2, distance_y=(@battlefield.height/2)-@size*2, min_distance = @size * 5)
    distance_x = [@size * 2, distance_x].max
    distance_y = [@size * 2, distance_y].max
    N_TRY.times.each do |i|
      x = random_axis @x, distance_x
      y = random_axis @y, distance_y
      if @battlefield.robots.any? {|robot|
          if robot.x == robot.prev_x
            false
          else
            Math.hypot(robot.x - x, robot.y - y) < (min_distance + @size * 2.0 * (N_TRY - i) / N_TRY.to_f)
          end
        }
      else
        @x = x
        @y = y
        break
      end
    end
    @gun_heat = 3
    @heading = (SecureRandom.random_number * 360).to_i
    @gun_heading = @heading
    @radar_heading = @heading
    @old_radar_heading = @radar_heading
    @new_radar_heading = @radar_heading
  end

  def set_action_limits
    @fire_min, @fire_max = 0, 3
    @turn_min, @turn_max = -10, 10
    @turn_gun_min, @turn_gun_max = -30, 30
    @turn_radar_min, @turn_radar_max = -60, 60
    @accelerate_min, @accelerate_max = -1, 1
    @teleport_min, @teleport_max = 0, 100
    @say_max = 256
    @team_message_max = 65535
    @broadcast_max = 16
  end

  def hit bullet
    damage = bullet.energy
    @energy -= damage
    @events['got_hit'] << {
      from: bullet.origin.uniq_name,
      damage: damage,
    }
    bullet.origin.num_hit += 1
    if !bullet.origin.dead
      bullet.origin.energy += damage * 2/3 if bullet.origin.team != @team
      bullet.origin.events['hit'] << {
        to: uniq_name,
        damage: damage
      }
    end
    damage
  end

  def dead
    @energy <= 0
  end

  def zonbi?
    @energy <= 0.3
  end

  def clamp(var, min, max)
    val = 0 + var # to guard against poisoned vars
    if val > max
      max
    elsif val < min
      min
    else
      val
    end
  end

  def before_tick
    scan
  end

  def internal_tick
    update_state
    robot_tick
    parse_actions
    fire
    turn
    move
    @time += 1
  end

  def after_tick
    team_message
    speak
    broadcast
  end

  def parse_actions
    @actions.clear
    NUMERIC_ACTIONS.each{|an|
      @actions[an] = clamp(@robot.actions[an], send("#{an}_min"), send("#{an}_max"))
    }
    STRING_ACTIONS.each{|an|
      if @robot.actions[an] != 0
        @actions[an] = String(@robot.actions[an])[0, send("#{an}_max")]
      end
    }
    @actions
  end

  def state
    current_state = {}
    STATE_IVARS.each{|iv|
      current_state[iv] = send(iv)
    }
    current_state[:battlefield_width] = @battlefield.width
    current_state[:battlefield_height] = @battlefield.height
    current_state[:game_over] = @battlefield.game_over
    current_state[:num_robots] = @battlefield.robots.reject{|robot| robot.dead}.length
    current_state
  end

  def update_state
    new_state = state
    @robot.state = new_state
    new_state.each{|k,v|
      @robot.send("#{k}=", v) if @robot.respond_to? "#{k}="
    }
    @robot.events = @events.dup
    @robot.actions ||= Hash.new(0)
    @robot.actions.clear
  end

  def robot_tick
    unless zonbi?
      @robot.tick @robot.events
      @robot.auto @robot.events
    end
    @events.clear
  end

  def fire
    return if zonbi?
    @actions[:fire] = (@energy - 0.1) if @actions[:fire] > @energy
    if (@actions[:fire] > 0) && (@gun_heat == 0)
      @num_fire += 1
      bullet = Bullet.new(@battlefield, @x, @y, @gun_heading, 30, @actions[:fire]*3.3 , self)
      3.times{bullet.tick}
      @battlefield << bullet
      @gun_heat = 0.5 + @actions[:fire] / 1.2
      @energy -= @actions[:fire]
    end
    @gun_heat -= 0.1
    @gun_heat = 0 if @gun_heat < 0
  end

  def turn
    @old_radar_heading = @radar_heading
    @heading += @actions[:turn]
    @gun_heading += (@actions[:turn] + @actions[:turn_gun])
    @radar_heading += (@actions[:turn] + @actions[:turn_gun] + @actions[:turn_radar])
    @new_radar_heading = @radar_heading

    @heading %= 360
    @gun_heading %= 360
    @radar_heading %= 360
  end

  def move
    @speed = 0 if zonbi?
    @prev_speed = @speed
    @prev_x = @x
    @prev_y = @y
    @prev_heading = @heading

    @speed += @actions[:accelerate]
    # @speed = [8, @speed - 2].max if @speed > 8
    # @speed = [-8, @speed + 2].min if @speed < -8
    @speed = 8 if @speed > 8
    @speed = -8 if @speed < -8

    @x += Math::cos(@heading.to_rad) * @speed
    @y -= Math::sin(@heading.to_rad) * @speed

    after_move
  end

  def impact_to_damage(impact)
    impact * impact / 10
  end

  def after_move
    if @x - @size < 0 or @y - @size < 0 or @x + @size >= @battlefield.width or @y + @size >= @battlefield.height
      @x = @size if @x - @size < 0
      @y = @size if @y - @size < 0
      @x = @battlefield.width - @size if @x + @size >= @battlefield.width
      @y = @battlefield.height - @size if @y + @size >= @battlefield.height
      impact = @speed.abs - Math.hypot(@y - @prev_y, @x - @prev_x)
      if impact > 0.1
        @speed = 0
        damage = impact_to_damage(impact)
        @energy -= damage
        @ram_damage_taken += damage
        @events['crash_into_wall'] << {
          damage: damage
        }
      end
    end
  end

  def scan
    return if @bot
    @battlefield.robots.each_with_index do |other, index|
      if (other != self) && (!other.dead)
        a = Math.atan2(@y - other.y, other.x - @x) / Math::PI * 180 % 360
        if (@old_radar_heading <= a && a <= @new_radar_heading) || (@old_radar_heading >= a && a >= @new_radar_heading) ||
          (@old_radar_heading <= a+360 && a+360 <= @new_radar_heading) || (@old_radar_heading >= a+360 && a+360 >= new_radar_heading) ||
           (@old_radar_heading <= a-360 && a-360 <= @new_radar_heading) || (@old_radar_heading >= a-360 && a-360 >= @new_radar_heading)
          @events['robot_scanned'] << {
            distance: Math.hypot(@y - other.y, other.x - @x),
            direction: to_direction({x: @x, y: @y}, {x: other.x, y: other.y}),
            energy: other.energy,
            name: other.uniq_name,
          }
        end
      end
    end
  end

  def speak
    if @actions[:say] != 0
      @speech = @actions[:say]
      @speech_counter = 50
    elsif @speech and (@speech_counter -= 1) < 0
      @speech = nil
    end
  end

  def team_message
    @team_members.each do |other|
      if (other != self) && (!other.dead)
        if other.actions[:team_message] != 0
          @events['team_messages'] << {
            from: other.uniq_name,
            message: other.actions[:team_message].to_s
          }
        end
      end
    end
  end

  def broadcast
    @battlefield.robots.each do |other|
      if (other != self) && (!other.dead)
        msg = other.actions[:broadcast]
        if msg != 0
          a = Math.atan2(@y - other.y, other.x - @x) / Math::PI * 180 % 360
          dir = 'east'
          dir = 'north' if a.between? 45,135
          dir = 'west' if a.between? 135,225
          dir = 'south' if a.between? 225,315
          @events['broadcasts'] << [msg, dir]
        end
      end
    end
  end

  def to_s
    @robot.class.name
  end

  def name
    @robot.class.name
  end

  def game_over
    @robot.game_over
  end
end
