class FiberStorm
  module Logging
    
    def logger
      self
    end
    
    def debug(message)
      @logger && @logger.debug("#{Fiber.current} #{message}")
    end
    
    def info(message)
      @logger && @logger.info(message)
    end
    
    def warn(message)
      @logger && @logger.warn(message)
    end
    
    def error(message)
      @logger && @logger.error(message)
    end
    
    def fatal(message)
      @logger && @logger.fatal(message)
    end
    
  end
end