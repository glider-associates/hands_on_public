require 'rrobots'
require "#{File.dirname(__FILE__)}/utils/sample"

class AntiYamaguchi
  include Robot
  include SampleUtil

  def tick events
    @random_angle ||= 0
    @random_angle = (SecureRandom.random_number * 60 + 60) * (SecureRandom.random_number < 0.5 ? 1 : -1) if time % 25 == 0
    @turn_angle = 0
    if x < @size * 2
      @turn_angle = -heading
    elsif y < @size * 2
      @turn_angle = -90 - heading
    elsif x > battlefield_width - @size * 2
      @turn_angle = 180 - heading
    elsif y > battlefield_height - @size * 2
      @turn_angle = 90 - heading
    end
    scan_for_fire
    target = @scanned_by_name.values.compact.select{|robot|
      (time - robot[:latest]) < 8
    }.first
    if target
      if target[:name] =~ /^Bao/
        @target_energy ||= target[:energy]
        @target_energy - target[:energy]
        if @target_energy != target[:energy]
          stop
          @random_angle += 90
          @turn_angle += 90
        end
        @target_energy = target[:energy]
        @random_angle = 90
      end
      accelerate_with_random 1, true
      if @turn_angle == 0
        @turn_angle = (target[:direction] - heading) + @random_angle
      end
      @turn_angle -= 360 if @turn_angle > 180
      @turn_angle += 360 if @turn_angle < -180
      if target[:name] =~ /^Yamaguchi/
        shoot_uniform_speed 0.5
      elsif target[:name] =~ /^Watanabe/
        @random_angle = (SecureRandom.random_number * 60 + 90) * (SecureRandom.random_number < 0.5 ? 1 : -1) if time % 25 == 0
        shoot_uniform_speed 1
      elsif target[:name] =~ /^Sekine/
        shoot_uniform_speed 1
      else
        shoot_uniform_speed 3
      end
      turn @turn_angle
    else
      accelerate_with_random 1, true
    end
  rescue => e
   p e
  end
end
