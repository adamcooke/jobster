require 'bunny'
require 'jobster/job'
require 'jobster/worker'
require 'jobster/version'

module Jobster

  class << self

    def bunny
      @bunny ||= begin
        connection = Bunny.new
        connection.start
        connection
      end
    end
    attr_writer :bunny

    def logger
      @logger ||= Logger.new(STDOUT)
    end
    attr_writer :logger

    def queue_prefix
      @queue_prefix ||= "jobster"
    end
    attr_writer :queue_prefix

    def exchange_name
      @exchange_name ||= "jobster"
    end
    attr_writer :exchange_name

    def delay_exchange_name
      "#{exchange_name}-delay-exch"
    end

    def delay_queue_name
      "#{exchange_name}-delay-queue"
    end

    def channel
      @channel ||= bunny.create_channel(nil, Worker.threads)
    end

    def exchange
      @exchange ||= channel.exchange(self.exchange_name, :type => :direct, :durable => true, :auto_delete => false)
    end

    def delay_exchange
      @delay_exchange ||= channel.exchange(delay_exchange_name, :type => :fanout, :durable => true, :auto_delete => false)
    end

    def delay_queue
      @delay_queue ||= begin
        queue = channel.queue(delay_queue_name, :durable => true, :auto_delete => false, :arguments => {'x-dead-letter-exchange' => self.exchange_name})
        queue.bind(delay_exchange)
        queue
      end
    end

    def queue(name)
      @queues ||= {}
      @queues[name] ||= begin
        queue = channel.queue("#{queue_prefix}-#{name}-we", :durable => true, :auto_delete => false)
        queue.bind(exchange, :routing_key => name)
        queue
      end
    end

  end

end
