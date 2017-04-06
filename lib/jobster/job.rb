module Jobster
  class Job

    class Abort < StandardError; end

    attr_reader :id
    attr_reader :params

    def initialize(id, params = {})
      @id = id
      @params = params.with_indifferent_access
    end

    def perform
      # Override in child jobs
    end

    def log(text)
      Jobster.logger.info "[#{@id}] #{text}"
    end

    def self.queue(queue = {}, params = {})
      if queue.is_a?(Hash)
        params = queue
        queue = :main
      end
      self.queue_job(Jobster.exchange, queue, self.name, params)
    end

    def self.queue_with_delay(delay, queue = {}, params = {})
      if queue.is_a?(Hash)
        params = queue
        queue = :main
      end
      self.queue_job(Jobster.delay_exchange, queue, self.name, params, :ttl => delay * 1000)
    end

    def self.queue_job(exchange, queue_name, class_name, params, options = {})
      job_id = SecureRandom.uuid[0,8]
      job_payload = {'params' => params, 'class_name' => class_name, 'id' => job_id, 'queue' => queue_name}

      publish_opts = {}
      publish_opts[:persistent] = true
      publish_opts[:routing_key] = queue_name
      publish_opts[:expiration] = options[:ttl] if options[:ttl]
      a = exchange.publish(job_payload.to_json, publish_opts)
      job_id
    end

    def self.perform(params = {})
      new(nil, params).perform
    end

  end
end
