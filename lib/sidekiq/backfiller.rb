# frozen_string_literal: true

require_relative "backfiller/version"
require_relative "backfiller/worker"

module Sidekiq
  module Backfiller
    def self.logger
      @logger ||= begin
        logger = Logger.new($stdout)
        logger.formatter = proc do |severity, datetime, progname, msg|
          "#{datetime}: [#{severity}] - #{msg}\n"
        end
        logger
      end
    end

    def self.logger=(logger)
      @logger = logger
    end
  end
end
