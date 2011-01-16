require "fiber"
require "fiber_storm/fiber_condition_variable"
require "fiber_storm/execution"
require "fiber_storm/logging"
require "fiber_storm/profiling"
require "fiber_storm/worker"

class FiberStorm
  
  attr_reader :options, :fiber
  
  DEFAULTS = {
    :size => 2,
    :execute_blocks => false,
    :logger => nil,
    :em_run => true
  }
  
  include Logging
  include Profiling
  
  def initialize(options = {}, &block)
    @options    = DEFAULTS.merge(options)
    @fiber      = Fiber.current
    @queue      = []
    @executions = []
    @logger     = @options[:logger]
    @workers    = @options[:size].times.collect{ Worker.new(@queue, self, @logger) }
    @cond       = FiberConditionVariable.new
    run(&block) if block_given?
  end
  
  def run(options = {}, &block)
    options = @options.merge(options)
    @fiber = Fiber.new{ yield(self) }
    if options[:em_run]
      EM.run{ @fiber.resume }
    else
      @fiber.resume
    end
  end
  
  def execute(*args, &block)
    if block_given?
      execution = Execution.new(*args, &block)
    else
      execution = args.first
    end
    
    block_execute if execute_should_block?
    
    @executions << execution
    @queue << execution
    
    resume_idle_worker
  end
  
  def join
    @executions.each{ |execution| execution.join }
  end
  
  def sleep(seconds)
    f = Fiber.current
    EM::Timer.new(seconds){ f.resume }
    Fiber.yield
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