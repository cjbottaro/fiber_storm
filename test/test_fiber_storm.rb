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
      
    end
  end
  
  def test_execute_blocks
    FiberStorm.new :size => 2, :execute_blocks => true do |storm|
      mock.proxy(storm.instance_eval{@cond}).wait
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
    end
  end
  
  def test_timeout
    FiberStorm.new :size => 2, :timeout => 0.1 do |storm|
      execution = storm.execute{ storm.sleep(1) }
      storm.join
      assert execution.timeout?
    end
    
    FiberStorm.new :size => 2, :timeout => 1 do |storm|
      execution = storm.execute{ storm.sleep(0.1) }
      storm.join
      assert ! execution.timeout?
    end
    
    FiberStorm.new :size => 2, :timeout => 0.1 do |storm|
      storm.execute{ storm.sleep(1) }
      storm.execute{ storm.sleep(1) }
      storm.execute{ storm.sleep(1) }
      storm.join
      assert storm.executions.all?{ |execution| execution.timeout? }
    end
    
    # Non cooperative fiber case.
    FiberStorm.new :size => 2, :timeout => 0.1 do |storm|
      storm.execute{ sleep(0.2) }
      storm.join
      assert ! storm.executions[0].timeout?
    end
    
  end
  
  def test_states
    FiberStorm.new :size => 1 do |storm|
      f1 = nil
      e1 = FiberStorm::Execution.new{ f1 = Fiber.current; Fiber.yield }
      
      f2 = nil
      e2 = FiberStorm::Execution.new{ f2 = Fiber.current; Fiber.yield }
      
      assert e1.initialized?
      assert e2.initialized?
      
      storm.execute(e1)
      storm.execute(e2)
      
      assert e1.started?
      assert e2.queued?
      
      f1.resume
      f2.resume
      
      storm.join
      
      assert e1.finished?
      assert e2.finished?
    end
  end
  
end
