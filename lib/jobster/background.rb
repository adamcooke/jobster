require 'jobster/background_proxy'

module Jobster
  module Background

    def __background__(options = {})
      BackgroundProxy.new(self, options)
    end

  end
end

Object.send(:include, Jobster::Background)
