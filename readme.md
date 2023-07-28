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
                     queue: :low

  def backfill_query
    User.where(...)
  end

  def process(record)
    record.update!(name: "#{record.first_name} #{record.last_name}")
  end

end
```
