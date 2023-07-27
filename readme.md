## Sidekiq - spread_filler

* Things to solve for
  * Ability to spread out the work without exhausting resources
  * Chain the units of work together


```ruby
class MyWorker
  include Sidekiq::Worker
  include Sidekiq::Backfiller::Worker

  sidekiq_backfiller backfiller_records_per_run: 100,
                     backfiller_batch_size: 10,
                     backfiller_wait_time_till_next_run: 1.minute

  def perform(...)
    ...
  end

  private

  def backfill_query
    User.where(...)
  end

  def process(record)
    record.update!(name: "#{record.first_name} #{record.last_name}")
  end

end
```
