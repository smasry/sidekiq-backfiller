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
        # Callback before processing each record
        cattr_accessor :before_process_hook
        # Callback after processing each record
        cattr_accessor :after_process_hook
        # Callback before processing each batch
        cattr_accessor :before_batch_hook
        # Callback after processing each batch
        cattr_accessor :after_batch_hook
      end

      class_methods do
        def sidekiq_backfiller(records_per_run: 500, batch_size: 100, wait_time_till_next_run: 5.minutes, queue: :default, before_process_hook: nil, after_process_hook: nil, before_batch_hook: nil, after_batch_hook: nil)
          self.backfiller_records_per_run = records_per_run
          self.backfiller_batch_size = batch_size
          self.backfiller_wait_time_till_next_run = wait_time_till_next_run
          self.backfiller_queue = queue
          self.before_process_hook = before_process_hook
          self.after_process_hook = after_process_hook
          self.before_batch_hook = before_batch_hook
          self.after_batch_hook = after_batch_hook
        end
      end

      def perform(opts = {})
        opts = opts.deep_symbolize_keys!
        start_id = opts[:start_id] || 1
        end_id = opts[:end_id] || -1
        finish_id = start_id + backfiller_records_per_run - 1

        if end_id.positive? && end_id < finish_id
          finish_id = end_id
        end

        Sidekiq::Backfiller.logger.info("Backfilling records from #{start_id} to #{finish_id} with batch size of #{backfiller_batch_size}")
        backfill_data(start_id: start_id, finish_id: finish_id) do |batch|
          process_batch(batch)
        end
        opts = {
          "start_id" => finish_id + 1
        }
        opts["end_id"] = end_id if end_id.positive?

        self.class.set(queue: backfiller_queue).perform_in(backfiller_wait_time_till_next_run, opts) if finish_id < backfill_query.maximum(:id)
      end

      def backfill_query
        raise NotImplementedError, "You must implement backfill_query"
      end

      def process_record(record)
        raise NotImplementedError, "You must implement process"
      end

      protected

      def process_batch(batch)
        Sidekiq::Backfiller.logger.info "processing batch of #{batch.size} records starting with batch id #{batch.first.id}"
        before_batch_hook.call(batch) if before_batch_hook.present?
        batch.each do |record|
          process(record)
        end
        after_batch_hook.call(batch) if after_batch_hook.present?
      end

      def backfill_data(start_id:, finish_id:, &block)
        backfill_query.find_in_batches(start: start_id, finish: finish_id, batch_size: backfiller_batch_size) do |batch|
          yield batch
        end
      end

      def process(record)
        before_process_hook.call(record) if before_process_hook.present?
        process_record(record)
        after_process_hook.call(record) if after_process_hook.present?
      end
    end
  end
end
