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

      job_id = SecureRandom.uuid[0,8]
      job_payload = {'params' => params, 'class_name' => self.name, 'id' => job_id, 'queue' => queue}
      Jobster.queue(queue).publish(job_payload.to_json, :persistent => false)
      job_id
    end

    def self.perform(params = {})
      new(nil, params).perform
    end

  end
end
