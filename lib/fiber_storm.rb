require "fiber"
require "fiber_storm/execution"
require "fiber_storm/magic"
require "fiber_storm/worker"

class FiberStorm
  
  attr_reader :options
  
  DEFAULTS = {
    :size => 2
  }
  
  include Magic
  
  def initialize(options = {}, &block)
    @options    = DEFAULTS.merge(options)
    @queue      = []
    @executions = []
    @workers    = @options[:size].times.collect{ Worker.new(@queue, self) }
    run(&block) if block_given?
  end
  
  def run
    Fiber.new{ yield(self) }.resume
  end
  
  def execute(*args, &block)
    if block_given?
      execution = Execution.new(*args, &block)
    else
      execution = args.first
    end
    
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
  
  def resume_idle_worker
    idle_worker = @workers.detect{ |worker| worker.idle? } and idle_worker.resume
  end
  
end