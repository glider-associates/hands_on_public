require 'rrobots'
require "#{File.dirname(__FILE__)}/utils/sample"

class Shooter
  include Robot
  include SampleUtil

  def tick events
    quick_shoot
  end
end
