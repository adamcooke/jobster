require 'base64'

module Jobster
  class BackgroundJob < Job

    def perform
      object = Marshal.load(Base64.decode64(params['object']))
      args = Marshal.load(Base64.decode64(params['args']))
      object.send(params['method'], *args)
    end

    def self.description(params)
      "#{params['object_class']}#{params['method']}"
    end

  end
end
