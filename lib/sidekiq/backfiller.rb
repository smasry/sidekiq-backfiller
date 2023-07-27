# frozen_string_literal: true

require_relative "backfiller/version"
require_relative "backfiller/worker"

module Sidekiq
  module Backfiller
    def self.logger
      @logger ||= begin
        loggger = Logger.new($stdout)
        loggger.formatter = proc do |severity, datetime, progname, msg|
          "#{datetime}: [#{severity}] - #{msg}\n"
        end
        loggger
      end
    end

    def self.logger=(logger)
      @logger = logger
    end
  end
end
