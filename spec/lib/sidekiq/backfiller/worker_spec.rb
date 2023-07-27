RSpec.describe Sidekiq::Backfiller::Worker do
  before do
    200.times { BackfillableModel.create!(first_name: "John", last_name: "Smith") }
  end

  subject(:worker) do
    Class.new do
      include Sidekiq::Worker
      include Sidekiq::Backfiller::Worker

      sidekiq_backfiller backfiller_records_per_run: 100,
        backfiller_batch_size: 10,
        backfiller_wait_time_till_next_run: 1.minute

      def backfill_query
        BackfillableModel.all
      end

      def process(record)
        record.update!(name: "#{record.first_name} #{record.last_name}")
      end
    end
  end

  describe "perform" do
    let(:opts) { {} }
    let(:worker_instance) { worker.new }

    it "calls process for each record" do
      expect(worker_instance).to receive(:process).exactly(100).times
      worker_instance.perform(opts)
    end

    it "processes all of the batches" do
      expect(worker_instance).to receive(:process_batch).exactly(10).times
      worker_instance.perform(opts)
    end

    it "executes the process_block" do
      worker_instance.perform(opts)
      record = BackfillableModel.first
      expect(BackfillableModel.first.name).to eq("#{record.first_name} #{record.last_name}")
    end

    it "executes the process_block" do
      expect(worker).to receive(:perform_in).with(1.minute, "start_id" => 101)
      worker_instance.perform(opts)
    end
  end
end
