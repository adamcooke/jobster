module Jobster
  class Worker

    def initialize(queues = nil)
      @initial_queues = queues || self.class.queues || [:main]
      @active_queues = {}
      @running_jobs = []
      @process_name = $0
      set_process_name
    end

    def set_process_name
      prefix = @process_name.to_s
      prefix += " [exiting]" if @exit
      if @running_jobs.empty?
        $0 = "#{prefix} (idle)"
      else
        $0 = "#{prefix} (running #{@running_jobs.join(', ')})"
      end
    end

    def work
      logger.info "Jobster worker started (#{Jobster.config.worker_threads} thread(s))"
      run_callbacks :after_start

      Jobster.delay_queue # Declare it

      Signal.trap("INT")  { @exit = true; set_process_name }
      Signal.trap("TERM") { @exit = true; set_process_name }

      Jobster.channel.prefetch(Jobster.config.worker_threads)
      @initial_queues.uniq.each { |queue | join_queue(queue) }

      exit_checks = 0
      loop do
        if @exit && @running_jobs.empty?
          logger.info "Exiting immediately because no jobs running"
          run_callbacks :before_quit, :immediate
          exit 0
        elsif @exit
          if exit_checks >= 300
            logger.info "Job did not finish in a timely manner. Exiting"
            run_callbacks :before_quit, :timeout
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

    def perform_job(class_name, params = {}, id = nil)
      id ||= SecureRandom.uuid[0,8]
      start_time = Time.now
      exception = nil
      logger.info "[#{id}] Started processing \e[34m#{class_name}\e[0m job"
      begin
        klass = Object.const_get(class_name).new(id, params)
        run_callbacks :before_job, klass
        klass.perform
      rescue Job::Abort => e
        exception = e
        logger.info "[#{id}] Job aborted (#{e.message})"
      rescue => e
        exception = e
        logger.warn "[#{id}] \e[31m#{e.class}: #{e.message}\e[0m"
        e.backtrace.each do |line|
          logger.warn "[#{id}]    " + line
        end
        Jobster.config.worker_error_handlers.each { |handler| handler.call(e, klass) }
      ensure
        run_callbacks :after_job, klass, exception
        logger.info "[#{id}] Finished processing \e[34m#{class_name}\e[0m job in #{Time.now - start_time}s"
      end
    end

    private

    def receive_job(properties, body)
      begin
        message = JSON.parse(body) rescue nil
        if message && message['class_name']
          Thread.current[:job_id] = message['id']
          @running_jobs << message['id']
          set_process_name
          perform_job(message['class_name'], message['params'] || {}, message['id'])
        end
      ensure
        Thread.current[:job_id] = nil
        @running_jobs.delete(message['id']) if message['id']
        set_process_name
        if @exit && @running_jobs.empty?
          logger.info "Exiting because all jobs have finished."
          run_callbacks :before_quit, :job_completed
          exit 0
        end
      end
    end

    def join_queue(queue)
      if @active_queues[queue]
        logger.info "Attempted to join queue #{queue} but already joined."
      else
        run_callbacks :before_queue_join, queue
        consumer = Jobster.queue(queue).subscribe(:manual_ack => true) do |delivery_info, properties, body|
          begin
            receive_job(properties, body)
          ensure
            Jobster.channel.ack(delivery_info.delivery_tag)
          end
        end
        @active_queues[queue] = consumer
        run_callbacks :after_queue_join, queue, consumer
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
      Jobster.config.logger
    end

    def self.queues
      @queues ||= [:main]
    end

    def run_callbacks(event, *args)
      if callbacks = Jobster.config.worker_callbacks[event]
        callbacks.each do |callback|
          callback.call(*args)
        end
      end
    end

  end
end
