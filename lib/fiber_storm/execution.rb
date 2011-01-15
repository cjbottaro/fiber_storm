require "fiber_storm/magic"

class FiberStorm
  class Execution
    
    include Magic
    
    attr_reader :fiber
    
    def initialize(*args, &block)
      @args       = args
      @block      = block
      @finished   = false
      @exception  = nil
      @fiber      = Fiber.current
    end
    
    def execute
      @block.call(@args)
      @finished = true
      waiter(:join).resume if waiting?(:join)
    end
    
    def finished?
      !!@finished
    end
    
    def join
      wait if not finished?
    end
    
  end
end