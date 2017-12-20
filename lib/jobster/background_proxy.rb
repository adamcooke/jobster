require 'base64'
require 'jobster/background_job'

module Jobster
  class BackgroundProxy

    class CannotQueueError < StandardError
    end

    def initialize(object, options = {})
      @object = object
      @options = options
    end

    def method_missing(method_name, *args, &block)
      if block_given?
        raise CannotQueueError, "Calling a method with a block cannot be queued"
      elsif !@object.respond_to?(method_name)
        raise CannotQueueError, "Method '#{method_name}' is not valid for #{@object.inspect}"
      else
        # Queue the job...
        object_dump = Base64.encode64(Marshal.dump(@object))
        args_dump = Base64.encode64(Marshal.dump(args))
        BackgroundJob.queue(@options[:queue] || :main, {'object_class' => @object.class == Class ? @object.name + "." : @object.class.name + "#", 'method' => method_name, 'args' => args_dump, 'object' => object_dump})
      end
    end

  end
end
