require 'gosu'

BIG_FONT = 'Courier New'
SMALL_FONT = 'Courier New'
COLORS = ['white', 'blue', 'yellow', 'red', 'lime']
FONT_COLORS = [0xffffffff, 0xff0008ff, 0xfffff706, 0xffff0613, 0xff00ff04]
X_PADDING = 264
Y_PADDING = 24
GosuRobot = Struct.new(:body, :gun, :radar, :speech, :info, :status, :color, :font_color)

module ZOrder
  Background, Robot, Explosions, UI = *0..3
end

class RRobotsGameWindow < Gosu::Window
  attr_reader :battlefield, :xres, :yres
  attr_accessor :on_game_over_handlers, :boom, :robots, :bullets, :explosions

  def initialize(battlefield, xres, yres)
    super(xres+X_PADDING, yres+Y_PADDING, false, 16)
    self.caption = 'RRobots'
    @font = Gosu::Font.new(self, BIG_FONT, 24)
    @small_font = Gosu::Font.new(self, SMALL_FONT, 24) #xres/100
    @battlefield = battlefield
    @xres, @yres = xres, yres
    @on_game_over_handlers = []
    init_window
    init_simulation
    @leaderboard = Leaderboard.new(self, @robots, @battlefield)
  end

  def on_game_over(&block)
    @on_game_over_handlers << block
  end

  def init_window
    @boom = (0..14).map do |i|
      Gosu::Image.new(self, File.join(File.dirname(__FILE__),"../images/explosion#{i.to_s.rjust(2, '0')}.png"))
    end
    @bullet_image = Gosu::Image.new(self, File.join(File.dirname(__FILE__),"../images/bullet.png"))
  end

  def init_simulation
    @robots, @bullets, @explosions = {}, {}, {}
  end

  def draw
    simulate
    draw_battlefield
    @leaderboard.draw
    if button_down? Gosu::Button::KbEscape
      self.close
    end
  end

  def draw_battlefield
    Gosu.draw_rect(0,0,@xres,@yres,Gosu::Color.argb(0xff_222266), ZOrder::Background)
    draw_robots
    draw_bullets
    draw_explosions
  end

  def simulate(ticks=1)
    @explosions.reject!{|e,tko| e.dead }
    @bullets.reject!{|b,tko| b.dead }
    @robots.reject! { |ai,tko| ai.dead}
    ticks.times do
      if @battlefield.game_over
        @on_game_over_handlers.each{|h| h.call(@battlefield) }
          winner = @robots.keys.first
          whohaswon = if winner.nil?
            "Draw!"
          elsif @battlefield.teams.all?{|k,t|t.size<2}
            "#{winner.uniq_name} won!"
          else
            "Team #{winner.team} won!"
          end
          text_color = winner ? winner.team : 7
          @font.draw_rel("#{whohaswon}", xres/2, yres/2, ZOrder::UI, 0.5, 0.5, 1, 1, 0xffffff00)
      else
        @battlefield.tick
      end
    end
  end

  def draw_robots
    unless @bodies
      @bodies = {}
      COLORS.each do |color|
        @bodies[color] =  Gosu::Image.new(self, File.join(File.dirname(__FILE__),"../images/#{color}_body000.png"))
      end
    end
    unless @turrets
      @turrets = {}
      COLORS.each do |color|
        @turrets[color] =  Gosu::Image.new(self, File.join(File.dirname(__FILE__),"../images/#{color}_turret000.png"))
      end
    end
    unless @radars
      @radars = {}
      COLORS.each do |color|
        @radars[color] =  Gosu::Image.new(self, File.join(File.dirname(__FILE__),"../images/#{color}_radar000.png"))
      end
    end
    @battlefield.robots.each_with_index do |ai, i|
      next if ai.dead
      default_font_color = FONT_COLORS[i % FONT_COLORS.size]
      default_color = COLORS[i % COLORS.size]
      @robots[ai] ||= GosuRobot.new(
        nil,
        nil,
        nil,
        @small_font,
        @small_font,
        @small_font,
        default_color,
        nil
      )
      @robots[ai].font_color = FONT_COLORS[COLORS.index(ai.font_color)] if COLORS.include? ai.font_color
      @robots[ai].font_color ||= default_font_color
      @robots[ai].body = @bodies[ai.body_color] || @bodies[default_color]
      @robots[ai].gun = @turrets[ai.turret_color] || @turrets[default_color]
      @robots[ai].radar = @radars[ai.radar_color] || @radars[default_color]

      @robots[ai].body.draw_rot(ai.x / 2, ai.y / 2, ZOrder::Robot, (-(ai.heading-90)) % 360)
      @robots[ai].gun.draw_rot(ai.x / 2, ai.y / 2, ZOrder::Robot, (-(ai.gun_heading-90)) % 360)
      @robots[ai].radar.draw_rot(ai.x / 2, ai.y / 2, ZOrder::Robot, (-(ai.radar_heading-90)) % 360)

      @robots[ai].speech.draw_rel(ai.speech.to_s, ai.x / 2, ai.y / 2 - 40, ZOrder::UI, 0.5, 0.5, 1, 1, @robots[ai].font_color)
      @robots[ai].info.draw_rel("#{ai.uniq_name}", ai.x / 2, ai.y / 2 + 30, ZOrder::UI, 0.5, 0.5, 1, 1, @robots[ai].font_color)
      @robots[ai].info.draw_rel("#{ai.energy.to_i}", ai.x / 2, ai.y / 2 + 50, ZOrder::UI, 0.5, 0.5, 1, 1, @robots[ai].font_color)
    end
  end

  def draw_bullets
    @battlefield.bullets.each do |bullet|
      @bullets[bullet] ||= @bullet_image
      @bullets[bullet].draw(bullet.x / 2, bullet.y / 2, ZOrder::Explosions)
    end
  end

  def draw_explosions
    @battlefield.explosions.each do |explosion|
      @explosions[explosion] = boom[explosion.t % 14]
      @explosions[explosion].draw_rot(explosion.x / 2, explosion.y / 2, ZOrder::Explosions, 0)
    end
  end
end
