# Ruby requires.
require "fiber"

# Gem requires.
require "eventmachine"

# Lib requires.
require "fiber_storm/fiber_condition_variable"
require "fiber_storm/execution"
require "fiber_storm/logging"
require "fiber_storm/profiling"
require "fiber_storm/worker"
require "fiber_storm/timeout"

class FiberStorm
  
  # The options passed into FiberStorm.new.
  attr_reader :options
  
  # Every call to #execute will result in an execution being appended to this array.
  attr_reader :executions
  
  DEFAULTS = {
    :size => 2,
    :execute_blocks => false,
    :timeout => nil,
    :logger => nil,
    :em_run => true,
    :em_stop => true
  }
  
  include Logging
  include Profiling
  extend FiberStorm::Timeout
  
  class << self
    public :timeout
  end
  
  # call-seq:
  #   new(options = {}){ |storm| ... }
  #
  # Create a new FiberStorm.  Valid _options_ are:
  # [:size] How many fibers in the fiber pool. In other words, the max concurrency level. Default is 2.
  # [:execute_blocks] If true, then #execute will block until a fiber is available. Default is false.
  # [:timeout] How long an execution can run before an attempt is made to aborted it. Default is nil (no timeout).
  # [:em_run] If true, then call EM.run at the beginning of #run. Default is true.
  # [:em_stop] If true, then call EM.stop at the end of #run. Default is true.
  # [:logger] Specify a Logger object. Default is nil (no logging).
  # If called with a block, then it is the same as:
  #   FiberStorm.new(options).run{ |storm| ... }
  def initialize(options = {}, &block)
    @options    = DEFAULTS.merge(options)
    @queue      = []
    @executions = []
    @logger     = @options[:logger]
    @workers    = @options[:size].times.collect{ Worker.new(@queue, self, @logger) }
    @cond       = FiberConditionVariable.new
    run(&block) if block_given?
  end
  
  # call-seq:
  #   run{ |storm| ... }
  # Wrap the block in a fiber and calls to EM.run and EM.stop (if specified in the options passed to
  # FiberStorm.new).
  def run(&block)
    fiber = Fiber.new do
      yield(self)
      EM.stop if options[:em_stop]
    end
    if options[:em_run]
      EM.run{ fiber.resume }
    else
      fiber.resume
    end
  end
  
  # call-seq:
  #   execution(options = {})
  #   execution(*args){ |*args| ... }
  #
  # Create a new Execution, passing it the options from this FiberStorm instance.  If called with
  # an _options_ hash, then it is the same as:
  #   Execution.new(storm.options.merge(options))
  # If it is called with a block, then it is the same as:
  #   Execution.new(storm.options).define(*args){ |*args| ... }
  def execution(*args, &block)
    if block_given?
      Execution.new(options).define(*args, &block)
    elsif args.length == 1
      Execution.new(options.merge(args.first))
    elsif args.length == 0
      Execution.new(options)
    else
      raise ArgumentError, "invalid call-seq"
    end
  end
  
  alias_method :new_execution, :execution
  
  # call-seq:
  #   execute(execution)
  #   execute(*args){ |*args| ... }
  #
  # Schedule an Execution to be run.  The execution will be added to the executions array immediately,
  # and run as soon as a fiber is available.  If called with a block, then it is the same as:
  #   execution = storm.execution(*args){ |*args| ... }
  #   storm.execute(execution)
  def execute(*args, &block)
    if block_given?
      execution = self.execution(*args, &block)
    else
      execution = args.first
    end
    
    execution.options.replace(options.dup)
    
    block_execute if execute_should_block?
    
    @executions << execution
    @queue << execution
    execution.send(:enter_state, Execution::STATE_QUEUED)
    
    resume_idle_worker
    
    execution
  end
  
  # Block until all scheduled executions have finished.
  def join
    @executions.each{ |execution| execution.join }
  end
  
  # Fiber aware sleep.  Do not call Kernel.sleep; it will halt the entire program.
  def self.sleep(seconds)
    f = Fiber.current
    EM::Timer.new(seconds){ f.resume }
    Fiber.yield
  end
  
  # Fiber aware sleep.
  def sleep(seconds) #:nodoc:
    self.class.sleep(seconds)
  end

  # Removes executions stored at FiberStorm#executions.  You can selectively remove
  # them by passing in a block or a symbol.  The following two lines are equivalent.
  #   storm.clear_executions(:finished?)
  #   storm.clear_executions{ |e| e.finished? }
  def clear_executions(method_name = nil, &block)
    cleared   = []
    remaining = []
    @executions.each do |execution|
      if block_given?
        if yield(execution)
          cleared << execution
        else
          remaining << execution
        end
      elsif method_name.nil?
        cleared << execution
      else
        if execution.send(method_name)
          cleared << execution
        else
          remaining << execution
        end
      end
    end
    @executions = remaining
    cleared
  end

  # Returns an array of Ruby fibers in the pool.
  def fibers
    @workers.collect{ |worker| worker.fiber }
  end

  alias_method :primitives, :fibers
  
private

  def idle_worker?
    @workers.any?{ |worker| worker.idle? }
  end
  
  def idle_worker
    @workers.detect{ |worker| worker.idle? }
  end
  
  def resume_idle_worker
    idle_worker.tap{ |worker| worker.resume if worker }
  end
  
  def block_execute
    profile("execute blocked %t"){ @cond.wait }
  end
  
  def execute_should_block?
    options[:execute_blocks] and not idle_worker?
  end
  
end
