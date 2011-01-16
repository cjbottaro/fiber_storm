class FiberStorm
  module Profiling
    
    # call-seq:
    #   profile(message){ ... }
    #   profile(log_level, message){ ... }
    # 
    # Write _message_ to the logger where %t in the message will be replaced with how long the block took to run.
    def profile(*args, &block)
      if args.length == 2
        level, message = args
      elsif args.length == 1
        level, message = :debug, args.first
      else
        raise ArgumentError, "invalid call-seq"
      end
      
      start_time = Time.now
      block.call
      elapsed_time = Time.now - start_time
      
      logger.send(level, message.gsub("%t", elapsed_time.to_s))
    end
    
  end
end