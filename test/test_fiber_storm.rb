require 'helper'

class TestFiberStorm < Test::Unit::TestCase
  
  def test_concurrency
    FiberStorm.new :size => 2 do |storm|
      count = 0
      
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
    end
  end
  
  def test_execute_blocks
    FiberStorm.new :size => 2, :execute_blocks => true do |storm|
      mock.proxy(storm).wait(:execute)
      count = 0
      
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
      assert_equal 3, count
    
      storm.execute do
        count += 1
        storm.sleep(0.1)
      end
      assert_equal 4, count
      
      storm.join
      EM.stop
    end
  end
  
end
