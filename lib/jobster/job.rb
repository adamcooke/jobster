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
      Jobster.config.logger.info "[#{@id}] #{text}"
    end

    def self.queue(queue = {}, params = {})
      queue, params = parse_args_for_queue(queue, params)
      self.queue_job(Jobster.exchange, queue, self.name, params)
    end

    def self.queue_with_delay(delay, queue = {}, params = {})
      queue, params = parse_args_for_queue(queue, params)
      self.queue_job(Jobster.delay_exchange, queue, self.name, params, :ttl => delay)
    end

    def self.parse_args_for_queue(queue, params)
      queue.is_a?(Hash) ? [:main, queue] : [queue, params]
    end

    def self.queue_job(exchange, queue_name, class_name, params, options = {})
      job_id = SecureRandom.uuid[0,8]
      job_payload = {'params' => params, 'class_name' => class_name, 'id' => job_id, 'queue' => queue_name}
      publish_opts = {}
      publish_opts[:persistent] = true
      publish_opts[:routing_key] = queue_name
      publish_opts[:expiration] = options[:ttl] * 1000 if options[:ttl]
      a = exchange.publish(job_payload.to_json, publish_opts)
      when_string = (options[:ttl] ? "in #{options[:ttl]}s" : "immediately")
      Jobster.config.logger.info "[#{job_id}] \e[34m#{class_name}\e[0m queued to run #{when_string} on #{queue_name} queue"
      job_id
    end

    def self.perform(params = {})
      new(nil, params).perform
    end

  end
end
