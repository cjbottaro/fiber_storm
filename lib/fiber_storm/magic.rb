class FiberStorm
  module Magic
    
    def wait
      name = caller.first.match(/in `(.+)'/)[1]
      instance_variable_set("@#{name}_fiber", Fiber.current)
      Fiber.yield
      instance_variable_set("@#{name}_fiber", nil)
    end
    
    def proceed(name, *args)
      fiber = instance_variable_get("@#{name}_fiber") and fiber.resume(*args)
    end
    
  end
end