## Sidekiq - spread_filler

* Things to solve for
  * Ability to spread out the work without exhausting resources
  * Chain the units of work together


```ruby
class MyWorker
  include Sidekiq::Job
  include Sidekiq::Backfiller

  sidekiq_backfiller(
    units_per_job: 1000,
    batch_size: 500
    spread_time: 1.minute
  )

  def perform(...)
    ...
  end

  private

  def backfill_base_query
    # id range will be automatically calculated based on the last run and units_per_job
    User.where(...)
  end

  def process_record(record)
    record.update!(full_name: "#{record.first_name} #{record.last_name}")
  end

end
```
