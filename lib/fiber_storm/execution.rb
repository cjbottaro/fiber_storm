require "fiber_storm/magic"

class FiberStorm
  class Execution
    
    include Magic
    
    def initialize(*args, &block)
      @args       = args
      @block      = block
      @finished   = false
      @exception  = nil
      @join_fiber = nil
    end
    
    def execute
      @block.call(@args)
      @finished = true
      proceed(:join)
    end
    
    def finished?
      !!@finished
    end
    
    def join
      wait if not finished?
    end
    
  end
end