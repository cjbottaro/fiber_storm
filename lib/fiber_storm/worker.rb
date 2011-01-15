require "fiber_storm/logging"
require "fiber_storm/magic"

class FiberStorm
  class Worker
    attr_reader :fiber
    
    include Magic
    include Logging
    
    def initialize(queue, storm, logger)
      @queue = queue
      @storm = storm
      @logger = logger
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
        if @storm.waiting?(:execute) or @storm.transferred?
          logger.debug "tranferring"
          transfer(@storm)
        else
          logger.debug "yielding"
          Fiber.yield
        end
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