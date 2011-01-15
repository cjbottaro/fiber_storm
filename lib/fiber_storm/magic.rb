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
    
    def resume(object, *args)
      fiber = object.instance_of?(Fiber) ? object : object.fiber
      fiber.resume(*args)
    end
    
    def transfer(object, *args)
      fiber = object.instance_of?(Fiber) ? object : object.fiber
      @transferred = true
      fiber.transfer(*args).tap{ @transferred = false }
    end
    
    def transferred?
      @transferred
    end
    
  end
end