require "fiber_storm/fiber_condition_variable"
require "fiber_storm/timeout"

class FiberStorm
  class Execution
    
    STATE_INITIALIZED = 0
    STATE_QUEUED      = 1
    STATE_STARTED     = 2
    STATE_FINISHED    = 3
    
    STATE_SYMBOLS = {
      :initialized  => STATE_INITIALIZED,
      :queued       => STATE_QUEUED,
      :started      => STATE_STARTED,
      :finished     => STATE_FINISHED
    }
    
    attr_reader :fiber
    attr_reader :options
    attr_reader :exception
    
    # call-seq:
    #   new(options = {})
    #   new(*args){ |*args| ... }
    #
    # Create a new execution.  It will not be scheduled to run until you pass it to FiberStorm#execute.
    def initialize(*args, &block)
      if block_given?
        @args    = args
        @block   = block
        @options = {}
      elsif args.first.kind_of?(Hash)
        @args    = []
        @block   = Proc.new{ nil }
        @options = args.first
      elsif args.length == 0
        @args    = []
        @block   = Proc.new{ nil }
        @options = {}
      end
      
      @state        = nil
      @state_times  = {}
      @finished     = false
      @exception    = nil
      @fiber        = Fiber.current
      @cond         = FiberConditionVariable.new
      
      enter_state(STATE_INITIALIZED)
    end
    
    # Sets the executions arguments and code block to run.
    def define(*args, &block)
      @args = args
      @block = block
    end
    
    def initialized?
      @state == STATE_INITIALIZED
    end
    
    def queued?
      @state == STATE_QUEUED
    end
    
    def started?
      @state == STATE_STARTED
    end
    
    def finished?
      @state == STATE_FINISHED
    end
    
    def success?
      finished? and !exception
    end
    
    def timeout?
      finished? and exception.kind_of?(TimeoutError)
    end
    
    def failure?
      finished? and !!exception and !timeout?
    end
    
    def execute
      enter_state(STATE_STARTED)
      begin
        do_execute
      rescue TimeoutError => e
        @exception = e
      rescue StandardError => e
        @exception = e
      end
      enter_state(STATE_FINISHED)
      @cond.signal
    end
    
    def join
      @cond.wait if not finished?
    end
    
  private
    
    def do_execute
      if options[:timeout]
        FiberStorm.timeout(options[:timeout]){ @block.call(@args) }
      else
        @block.call(@args)
      end
    end
    
    def enter_state(state)
      @state_times[state] = Time.now
      @state = state
    end
    
  end
end