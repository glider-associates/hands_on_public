require 'rrobots'
require "#{File.dirname(__FILE__)}/utils/sample"

require 'securerandom'

class RandomCrawler
  include Robot
  include SampleUtil

  def tick events
    @back ||= 0
    if events['crash_into_enemy'].length > 0 or @back > 0
      @back = 16 if @back == 0
      @back -= 1
      accelerate -1
    else
      accelerate 1
    end

    if x < @size * 2
      turn -heading
      return
    elsif y < @size * 2
      turn -90 - heading
      return
    elsif x > battlefield_width - @size * 2
      turn 180 - heading
      return
    elsif y > battlefield_height - @size * 2
      turn 90 - heading
      return
    end

    @turn_angle ||= 0
    if (time % 40) == 0
      @turn_angle = 20 * SecureRandom.random_number - 10
    end
    if (time % 40) < 18
      turn @turn_angle
    else
      @turn_angle = 0
    end

    shoot_uniform_speed

    @scanned_by_name.values.compact.each do |robot|
      if robot[:distance] < @size * 6 and (robot[:direction] - heading).abs < 90
        turn 10
      end
    end
  end
end
