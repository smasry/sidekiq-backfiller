# frozen_string_literal: true

require "sidekiq"
require "active_support/core_ext/hash/keys"
require "active_support/concern"
require_relative "metrics"

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
        # Callback when a record raises an error
        cattr_accessor :on_record_error
        # Callback when a batch raises an error
        cattr_accessor :on_batch_error
      end

      class_methods do
        def sidekiq_backfiller(records_per_run: 500, batch_size: 100, wait_time_till_next_run: 5.minutes, queue: :default, before_process_hook: nil, after_process_hook: nil, before_batch_hook: nil, after_batch_hook: nil, on_record_error: nil, on_batch_error: nil)
          self.backfiller_records_per_run = records_per_run
          self.backfiller_batch_size = batch_size
          self.backfiller_wait_time_till_next_run = wait_time_till_next_run
          self.backfiller_queue = queue
          self.before_process_hook = before_process_hook
          self.after_process_hook = after_process_hook
          self.before_batch_hook = before_batch_hook
          self.after_batch_hook = after_batch_hook
          self.on_record_error = on_record_error
          self.on_batch_error = on_batch_error
        end
      end

      def perform(opts = {})
        opts = opts.deep_symbolize_keys!
        start_id = opts[:start_id] || 1
        end_id = opts[:end_id] || -1
        @metrics = Metrics.new(processed: opts.dig(:backfiller, :processed), errors: opts.dig(:backfiller, :errors))
        finish_id = start_id + backfiller_records_per_run - 1

        if end_id.positive? && end_id < finish_id
          finish_id = end_id
        end

        Sidekiq::Backfiller.logger.info("Backfilling records from #{start_id} to #{finish_id} with batch size of #{backfiller_batch_size}")
        backfill_data(start_id: start_id, finish_id: finish_id) do |batch|
          process_batch(batch)
        rescue => e
          if on_batch_error.present?
            on_batch_error.call(batch, e)
          else
            raise e
          end
        end

        processed = ((opts.dig(:backfiller, :processed) || 0) - @metrics.processed).abs
        errors = ((opts.dig(:backfiller, :errors) || 0) - @metrics.errors).abs
        Sidekiq::Backfiller.logger.info("Batch completed. Processed #{processed} records with #{errors} errors")

        if finish_id < backfill_query.maximum(:id)
          self.class.set(queue: backfiller_queue).perform_in(backfiller_wait_time_till_next_run, next_run_opts(finish_id, end_id, @metrics))
        else
          Sidekiq::Backfiller.logger.info("Backfill Completed. Processed #{@metrics.processed} records with #{@metrics.errors} errors")
        end
      end

      def backfill_query
        raise NotImplementedError, "You must implement backfill_query"
      end

      def process_record(record)
        raise NotImplementedError, "You must implement process"
      end

      protected

      def next_run_opts(finish_id, end_id, metrics)
        opts = {
          "start_id" => finish_id + 1
        }

        opts["end_id"] = end_id if end_id.positive?
        opts.merge("backfiller" => {"metrics" => metrics.to_h})
      end

      def process_batch(batch)
        Sidekiq::Backfiller.logger.info "processing batch of #{batch.size} records starting with batch id #{batch.first.id}"
        before_batch_hook.call(batch) if before_batch_hook.present?
        batch.each do |record|
          process(record)
        end
        after_batch_hook.call(batch) if after_batch_hook.present?
      end

      def backfill_data(start_id:, finish_id:, &block)
        backfill_query.in_batches(of: backfiller_batch_size, start: start_id, finish: finish_id) do |batch|
          yield batch
        end
      end

      def process(record)
        before_process_hook.call(record) if before_process_hook.present?
        begin
          process_record(record)
          @metrics.increment_processed
        rescue => e
          @metrics.increment_errors
          if on_record_error.present?
            on_record_error.call(record, e)
          else
            raise e
          end
        end
        after_process_hook.call(record) if after_process_hook.present?
      end
    end
  end
end
