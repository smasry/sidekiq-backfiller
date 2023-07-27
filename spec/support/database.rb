ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.define do
  create_table :backfillable_models, force: true do |t|
    t.string :first_name
    t.string :last_name
    t.string :name
  end
end

RSpec.configure do |config|
  config.around do |example|
    ActiveRecord::Base.transaction do
      example.run

      raise ActiveRecord::Rollback
    end
  end
end

class BackfillableModel < ActiveRecord::Base; end
