# frozen_string_literal: true

module Sidekiq
  module Backfiller
    class Metrics
      attr_accessor :processed, :errors

      def initialize(processed: nil, errors: nil)
        @processed ||= 0
        @errors ||= 0
      end

      def increment_processed
        @processed += 1
      end

      def increment_errors
        @errors += 1
      end

      def to_h
        {
          "processed" => @processed,
          "errors" => @errors
        }
      end
    end
  end
end
