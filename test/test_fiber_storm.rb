require 'helper'

class TestFiberStorm < Test::Unit::TestCase
  
  def test_concurrency
    EM.run do
      Fiber.new do
        count = 0
        storm = FiberStorm.new :size => 2
      
        storm.execute do
          count += 1
          storm.sleep(0.1)
        end
        assert_equal 1, count
      
        storm.execute do
          count += 1
          storm.sleep(0.1)
        end
        assert_equal 2, count
      
        storm.execute do
          count += 1
          storm.sleep(0.1)
        end
        assert_equal 2, count
      
        storm.join
        assert_equal 3, count
      
        EM.stop
      end.resume
    end
  end
  
end
