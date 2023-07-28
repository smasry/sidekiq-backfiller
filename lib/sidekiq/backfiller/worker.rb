# frozen_string_literal: true

require "sidekiq"
require "active_support/core_ext/hash/keys"
require "active_support/concern"

module Sidekiq
  module Backfiller
    module Worker
      extend ActiveSupport::Concern

      included do
        # Max number of records for the worker to process per run
        cattr_accessor :backfiller_records_per_run
        # Max number of records to fetch from the database per batch
        cattr_accessor :backfiller_batch_size
        # Duration to wait before scheduling the next run
        cattr_accessor :backfiller_wait_time_till_next_run
        # Sidekiq queue to use for the backfiller
        cattr_accessor :backfiller_queue
      end

      class_methods do
        def sidekiq_backfiller(backfiller_records_per_run: 500, backfiller_batch_size: 100, backfiller_wait_time_till_next_run: 5.minutes, backfiller_queue: :default)
          self.backfiller_records_per_run = backfiller_records_per_run
          self.backfiller_batch_size = backfiller_batch_size
          self.backfiller_wait_time_till_next_run = backfiller_wait_time_till_next_run
          self.backfiller_queue = backfiller_queue
        end
      end

      def perform(opts = {})
        opts = opts.deep_symbolize_keys!
        start_id = opts[:start_id] || 1
        finish_id = start_id + backfiller_records_per_run - 1

        Sidekiq::Backfiller.logger.info("Backfilling records from #{start_id} to #{finish_id} with batch size of #{backfiller_batch_size}")
        backfill_data(start_id: start_id, finish_id: finish_id) do |batch|
          process_batch(batch)
        end

        self.class.set(queue: backfiller_queue).perform_in(backfiller_wait_time_till_next_run, "start_id" => finish_id + 1) if finish_id < backfill_query.maximum(:id)
      end

      def process_batch(batch)
        Sidekiq::Backfiller.logger.info "processing batch of #{batch.size} records starting with batch id #{batch.first.id}"
        batch.each do |record|
          Sidekiq::Backfiller.logger.debug("Processing record #{record.id}")
          process(record)
        end
      end

      def backfill_data(start_id:, finish_id:, &block)
        backfill_query.find_in_batches(start: start_id, finish: finish_id, batch_size: backfiller_batch_size) do |batch|
          yield batch
        end
      end

      def backfill_query
        raise NotImplementedError, "You must implement backfill_query"
      end

      def process(record)
        raise NotImplementedError, "You must implement process"
      end
    end
  end
end
