## Sidekiq - spread_filler

* Things to solve for
  * Ability to spread out the work without exhausting resources
  * Chain the units of work together


```ruby
class MyWorker
  include Sidekiq::Worker
  include Sidekiq::Backfiller::Worker

  sidekiq_backfiller records_per_run: 100,
                     batch_size: 10,
                     wait_time_till_next_run: 1.minute,
                     queue: :low,
                     before_process_hook: ->(record) { record.first_name = record.first_name.upcase } ,
                     after_process_hook: ->(record) { record.update!(processed: true) },
                     before_batch_hook: ->(batch) { Sidekiq::Backfiller.logger.info("Processing Batch starting with #{batch.first.id}") },
                     after_batch_hook: ->(batch) { Sidekiq::Backfiller.logger.info("Processed Batch starting with #{batch.first.id}") }

  def backfill_query
    User.where(...)
  end

  def process(record)
    record.update!(name: "#{record.first_name} #{record.last_name}")
  end

end

## Execute all records returned from backfill_query
MyWorker.perform_async


# Execute a range of ID's
opts = {
  "start_id" => 100
  "end_id" => 1000
}
MyWorker.perform_async(opts)
```
