require 'bunny'
require 'jobster/job'
require 'jobster/worker'
require 'jobster/version'
require 'jobster/config'

module Jobster

  def self.config
    @config ||= Config.new
  end

  def self.configure(&block)
    block.call(self.config)
  end

  def self.channel
    @channel ||= config.bunny.create_channel(nil, config.worker_threads)
  end

  def self.exchange
    @exchange ||= channel.exchange(config.exchange_name, :type => :direct, :durable => true, :auto_delete => false)
  end

  def self.delay_exchange
    @delay_exchange ||= channel.exchange(config.delay_exchange_name, :type => :fanout, :durable => true, :auto_delete => false)
  end

  def self.delay_queue
    @delay_queue ||= begin
      queue = channel.queue(config.delay_queue_name, :durable => true, :auto_delete => false, :arguments => {'x-dead-letter-exchange' => config.exchange_name})
      queue.bind(delay_exchange)
      queue
    end
  end

  def self.queue(name)
    @queues ||= {}
    @queues[name] ||= begin
      queue = channel.queue("#{config.queue_name_prefix}-#{name}", :durable => true, :auto_delete => false)
      queue.bind(exchange, :routing_key => name)
      queue
    end
  end

end
