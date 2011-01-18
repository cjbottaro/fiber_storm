require "fiber_storm/fiber_condition_variable"
require "fiber_storm/timeout"

class FiberStorm
  
  # An execution represents a unit of work to be done by the fiber pool.
  #
  # You shouldn't really create an execution directly, but rather go through FiberStorm#execute or
  # FiberStorm#execution so that the execution inherits the options from the FiberStorm instance.
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
    
    # The fiber that this execution was run on.
    attr_reader :fiber
    
    # The options for this execution.
    attr_reader :options
    
    # If the execution times out or raises an exception, it is stored here.
    attr_reader :exception
    
    # The execution's current state.
    attr_reader :state
    
    # call-seq:
    #   new(options = {})
    #   new(*args){ |*args| ... }
    #
    # Create a new execution.  It will not be scheduled to run until you pass it to FiberStorm#execute.
    # Valid _options_ are...
    # [:timeout] Maximum amount of time this execution should be allowed to run before trying to abort it.
    #            Default is nil (no timeout).
    # [:reraise] If an exception occurred, reraise it when #join is called.  Default is true.
    # [:default] What the execution's value should be set to in case of a timeout or exception.
    #            Default is nil.
    # If called with a block, then it is the same as:
    #   Execution.new.define(*args){ |*args| ... }
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
      @cond         = FiberConditionVariable.new
      
      enter_state(STATE_INITIALIZED)
    end
    
    # Sets the executions arguments and code block to run.
    #   storm = FiberStorm.new
    #   execution = Execution.new
    #   execution.define("Chris"){ |name| puts "Hello, #{name}!" }
    #   storm.execute(execution) # => "Hello, Chris!"
    def define(*args, &block)
      @args = args
      @block = block
      self
    end
    
    # Returns true if the execution is in STATE_INITIALIZED.
    def initialized?
      @state == STATE_INITIALIZED
    end
    
    # Returns true if the execution is in STATE_QUEUED.
    def queued?
      @state == STATE_QUEUED
    end
    
    # Returns true if the execution is in STATE_STARTED.
    def started?
      @state == STATE_STARTED
    end
    
    # Returns true if the execution is in STATE_FINISHED.
    def finished?
      @state == STATE_FINISHED
    end
    
    # Returns true if the execution finished without exception or timeout.
    def success?
      finished? and !exception
    end
    
    # Returns true if the execution timed out.
    def timeout?
      finished? and exception.kind_of?(TimeoutError)
    end
    
    # Returns true if the execution raised an exception while running.
    def failure?
      finished? and !!exception and !timeout?
    end
    
    # Run an execution's code block.  You shouldn't call this directly, but rather
    # schedule an execution to be run via FiberStorm#execute.
    def execute
      enter_state(STATE_STARTED)
      @fiber = Fiber.current
      begin
        @value = do_execute
      rescue TimeoutError => e
        @exception = e
      rescue StandardError => e
        @exception = e
      end
      @cond.signal
      enter_state(STATE_FINISHED)
    end
    
    # Block until the execution finishes.
    def join
      @cond.wait if not finished?
    end
    
  private
    
    def do_execute
      if options[:timeout]
        FiberStorm.timeout(options[:timeout]){ @block.call(*@args) }
      else
        @block.call(*@args)
      end
    end
    
    def enter_state(state)
      @state_times[state] = Time.now
      @state = state
    end
    
  end
end