class FiberStorm
  class Worker
    attr_reader :fiber
    
    def initialize(queue, storm)
      @queue = queue
      @storm = storm
      @busy  = false
      @fiber = Fiber.new{ run }
    end
    
    def run
      run_loop until stop?
    end
    
    def run_loop
      if (execution = @queue.shift)
        @busy = true
        execution.execute
      else
        @busy = false
        Fiber.yield
      end
    end
    
    def resume
      @fiber.resume
    end
    
    def alive?
      @fiber.alive?
    end
    
    def busy?
      !!@busy
    end
    
    def idle?
      !busy?
    end
    
    def stop!
      @stop = true
    end
    
    def stop?
      !!@stop
    end
    
  end
end