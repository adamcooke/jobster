module Jobster
  class Config

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

    def exchange_name
      @exchange_name || "jobster"
    end
    attr_writer :exchange_name

    def delay_exchange_name
      @delay_exchange_name || "#{self.exchange_name}-delay-exch"
    end
    attr_writer :delay_exchange_name

    def delay_queue_name
      @delay_queue_name || "#{self.exchange_name}-delay-queue"
    end
    attr_writer :delay_queue_name

    def queue_name_prefix
      @queue_name_prefix || "#{self.exchange_name}-queue"
    end
    attr_writer :queue_name_prefix

    def worker_threads
      @worker_threads || 1
    end
    attr_writer :worker_threads

    def worker_callbacks
      @worker_callbacks ||= {}
    end

    def worker_callback(name, &block)
      worker_callbacks[name.to_sym] ||= []
      worker_callbacks[name.to_sym] << block
    end

    def worker_error_handlers
      @worker_error_handlers ||= []
    end

    def worker_error_handler(&block)
      worker_error_handlers << block
    end

  end
end
