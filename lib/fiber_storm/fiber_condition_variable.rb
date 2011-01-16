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
      @fiber.tap{ |fiber| EM::Timer.new(0){ fiber.resume } if fiber }
    end
    
  end
end