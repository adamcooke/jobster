module Jobster
  class Worker

    def initialize(queues = nil)
      @initial_queues = queues || self.class.queues || [:main]
      @active_queues = {}
      @process_name = $0
    end

    def work
      logger.info "Jobster worker started"
      @running_job = false
      Signal.trap("INT")  { @exit = true }
      Signal.trap("TERM") { @exit = true }

      Jobster.channel.prefetch(1)
      @initial_queues.uniq.each { |queue | join_queue(queue) }

      exit_checks = 0
      loop do
        if @exit && @running_job == false
          logger.info "Exiting immediately because no job running"
          exit 0
        elsif @exit
          if exit_checks >= 300
            logger.info "Job did not finish in a timely manner. Exiting"
            exit 0
          end
          if exit_checks == 0
            logger.info "Exit requested but job is running. Waiting for job to finish."
          end
          sleep 5
          exit_checks += 1
        else
          sleep 1
        end
      end
    end

    private

    def receive_job(delivery_info, properties, body)
      @running_job = true
      begin
        message = JSON.parse(body) rescue nil
        if message && message['class_name']
          start_time = Time.now
          $0 = "#{@process_name} (running #{message['class_name']})"
          Thread.current[:job_id] = message['id']
          logger.info "[#{message['id']}] Started processing \e[34m#{message['class_name']}\e[0m job"
          begin
            klass = Object.const_get(message['class_name']).new(message['id'], message['params'])
            klass.perform
          rescue => e
            logger.warn "[#{message['id']}] \e[31m#{e.class}: #{e.message}\e[0m"
            e.backtrace.each do |line|
              logger.warn "[#{message['id']}]    " + line
            end
            self.class.error_handlers.each { |handler| handler.call(e, klass) }
          ensure
            logger.info "[#{message['id']}] Finished processing \e[34m#{message['class_name']}\e[0m job in #{Time.now - start_time}s"
          end
        end
      ensure
        Thread.current[:job_id] = nil
        $0 = @process_name
        Jobster.channel.ack(delivery_info.delivery_tag)
        @running_job = false
        if @exit
          logger.info "Exiting because a job has ended."
          exit 0
        end
      end
    end

    def join_queue(queue)
      if @active_queues[queue]
        logger.info "Attempted to join queue #{queue} but already joined."
      else
        consumer = Jobster.queue(queue).subscribe(:manual_ack => true) do |delivery_info, properties, body|
          receive_job(delivery_info, properties, body)
        end
        @active_queues[queue] = consumer
        logger.info "Joined \e[32m#{queue}\e[0m queue"
      end
    end

    def leave_queue(queue)
      if consumer = @active_queues[queue]
        consumer.cancel
        @active_queues.delete(queue)
        logger.info "Left \e[32m#{queue}\e[0m queue"
      else
        logger.info "Not joined #{queue} so cannot leave"
      end
    end

    def logger
      Jobster.logger
    end

    def self.queues
      @queues ||= [:main]
    end

    def self.error_handlers
      @error_handlers ||= []
    end

    def self.register_error_handler(&block)
      error_handlers << block
    end

  end
end
