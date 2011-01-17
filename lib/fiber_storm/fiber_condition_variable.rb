class FiberStorm
  class FiberConditionVariable
        
    def wait
      if @fiber
        raise RuntimeError, "already waiting"
      else
        @fiber = Fiber.current
        Fiber.yield.tap{ @fiber = nil }
      end
    end
    
    # Asynchronously signal the waiting fiber to run.
    def signal
      @fiber.tap{ |fiber| EM::next_tick{ fiber.resume } if fiber }
    end
    
  end
end