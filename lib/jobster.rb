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

    def ttl
      @ttl ||= 60 * 60 * 10
    end
    attr_writer :ttl

    def queue_prefix
      @queue_prefix ||= "jobster"
    end
    attr_writer :queue_prefix

    def channel
      @channel ||= bunny.create_channel(nil, Worker.threads)
    end

    def queue(name)
      @queues ||= {}
      @queues[name] ||= begin
        channel.queue("#{queue_prefix}-#{name}", :durable => true, :arguments => {'x-message-ttl' => self.ttl})
      end
    end

  end

end
