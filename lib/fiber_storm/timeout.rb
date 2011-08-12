require "fiber_storm/fiber_condition_variable"

class FiberStorm
  
  # Raised by FiberStorm.timeout.
  class TimeoutError < RuntimeError; end
  
  module Timeout
    
    # Fiber aware timeout.  Raises FiberStorm::TimeoutError
    # if block takes longer than _seconds_ to finish.
    # 
    # WARNING:  This timeout implementation relies on cooperative concurrency.  If the block does not
    #           ever call Fiber.yield, then the timeout code will never get a chance to run.  For
    #           example:
    #             timeout(1){ 100000.times{ rand * rand } }
    #           will never timeout.  The block will simply run until it is finished and +timeout+ will
    #           return without error.
    #
    # WARNING:  Every block you run within this timeout method will be run on a new fiber.  This may
    #           wreak havor on most fibered implementations of ActiveRecord's ConnectionPool.
    #
    # You can use this method direct via +FiberStorm.timeout+ or include FiberStorm::Timeout in a
    # class or module.
    def timeout(seconds, &block)
      me = Fiber.current
      timer = EM::Timer.new(seconds){ me.resume(:timeout) }

      them = Fiber.new do
        begin
          block.call(seconds)
        rescue Exception => e
          me.resume(e)
        else
          me.resume(:success)
        end
      end
      EM.next_tick{ them.resume }

      case result = Fiber.yield
      when :success
        timer.cancel
      when :timeout
        # I don't really know how to "kill" a fiber.  Overriding its resume method to do
        # nothing seems work pretty well (the next time EventMachine tries to resume it,
        # nothing will happen).  Note, I tried overriding resume to call Fiber.yield, but
        # got errors about the root fiber yielding.
        def them.resume(*args); nil; end
        raise TimeoutError, "execution expired"
      when Exception
        timer.cancel
        raise(result)
      end
    end
    
    module_function :timeout
    
  end
end
