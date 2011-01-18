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
  
  attr_reader :options
  
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
  
  def initialize(options = {}, &block)
    @options    = DEFAULTS.merge(options)
    @queue      = []
    @executions = []
    @logger     = @options[:logger]
    @workers    = @options[:size].times.collect{ Worker.new(@queue, self, @logger) }
    @cond       = FiberConditionVariable.new
    run(&block) if block_given?
  end
  
  def run(options = {}, &block)
    options = @options.merge(options)
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
  
  def execute(*args, &block)
    if block_given?
      execution = Execution.new(*args, &block)
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
  
  def join
    @executions.each{ |execution| execution.join }
  end
  
  def self.sleep(seconds)
    f = Fiber.current
    EM::Timer.new(seconds){ f.resume }
    Fiber.yield
  end
  
  def sleep(seconds)
    self.class.sleep(seconds)
  end
  
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