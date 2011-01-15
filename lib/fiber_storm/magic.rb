class FiberStorm
  module Magic
    
    def wait(name = nil)
      name ||= caller.first.match(/in `(.+)'/)[1].to_sym
      @waiters ||= {}
      @waiters[name] = Fiber.current
      Fiber.yield.tap{ @waiters[name] = false }
    end
    
    def waiter(name)
      @waiters ||= {}
      @waiters[name]
    end
    
    def waiting?(name)
      !!waiter(name)
    end
    
    def switch(object, *args)
      if object.transferred?
        logger.debug "transfer => #{fiber_for(object)}"
        transfer(object, *args)
      else
        logger.debug "resume => #{fiber_for(object)}"
        resume(object, *args)
      end
    end
    
    def resume(object, *args)
      fiber_for(object).resume(*args)
    end
    
    def transfer(object, *args)
      @transferred = true
      fiber_for(object).transfer(*args).tap{ @transferred = false }
    end
    
    def transferred?
      @transferred
    end
    
    def fiber_for(object)
      object.instance_of?(Fiber) ? object : object.fiber
    end
    
  end
end