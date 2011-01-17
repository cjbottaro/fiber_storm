require "fiber_storm/fiber_condition_variable"

class FiberStorm
  
  # Raised by FiberStorm.timeout.
  class TimeoutError < RuntimeError; end
  
  module Timeout
    
    # Fiber aware timeout.  Raises FiberStorm::TimeoutError
    # if block takes longer than _seconds_ to finish.
    # 
    # WARNING:  This timeout implementation relies on cooperative concurrency.  If the block does not
    # ever call Fiber.yield, then the timeout code will never get a chance to run.  For example:
    #   timeout(1){ 100000.times{ rand * rand } }
    # will never timeout.  The block will simply run until it is finished and +timeout+ will
    # return without error.
    #
    # You can use this method direct via +FiberStorm.timeout+ or include FiberStorm::Timeout in a
    # class or module.
    def timeout(seconds, &block)
       cond = FiberConditionVariable.new
       
       fiber = Fiber.new do
         block.call(seconds)
         cond.signal
       end
       fiber.resume
       
       # By this point, one of two things have happened:
       # 1)  fiber is completely done running, if so, we're done here.
       # 2)  fiber has yielded, but still has code to run.
       
       return unless fiber.alive?
       
       # Ok, so fiber is still alive.  We set a timer and wait (yield).
       
       timer = EM::Timer.new(seconds){ cond.signal } and cond.wait
       
       # Ok, we're back from waiting (yielding).  Either the timer resumed us or fiber did.
       
       if fiber.alive?
         # If fiber is still alive, that means the timer resumed us.
         
         # I don't really know how to "kill" a fiber.  Overriding its resume method to do
         # nothing seems work pretty well (the next time EventMachine tries to resume it,
         # nothing will happen).  Note, I tried overriding resume to call Fiber.yield, but
         # got errors about the root fiber yielding.
         def fiber.resume; nil; end
         
         # Unfortunatley, I don't know how to get a stack trace of where a
         # fiber is yielded, so we just raise the TimeoutError from here.
         raise TimeoutError, "execution expired"
       
       else
         # fiber is finished (not alive), that means it resumed us.
         
         timer.cancel # No need for the timer anymore.
       end
       
     end
    
    module_function :timeout
    
  end
end