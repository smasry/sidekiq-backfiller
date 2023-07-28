RSpec.describe Sidekiq::Backfiller::Worker do
  before do
    200.times { BackfillableModel.create!(first_name: "John", last_name: "Smith") }
  end

  subject(:worker) do
    Class.new do
      include Sidekiq::Job
      include Sidekiq::Backfiller::Worker

      sidekiq_backfiller records_per_run: 100,
        batch_size: 10,
        wait_time_till_next_run: 1.minute,
        queue: :low,
        after_process_hook: ->(record) { record.update!(processed: true) }

      def backfill_query
        BackfillableModel.all
      end

      def process_record(record)
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

    it "executes the process block" do
      worker_instance.perform(opts)
      record = BackfillableModel.first
      expect(BackfillableModel.first.name).to eq("#{record.first_name} #{record.last_name}")
    end

    it "enqueues the next run" do
      expect_any_instance_of(Sidekiq::Job::Setter).to receive(:perform_in).with(1.minute, "start_id" => 101)
      worker_instance.perform(opts)
    end

    it "sets the queue" do
      expect(worker).to receive(:set).with(queue: :low).and_call_original
      worker_instance.perform(opts)
    end

    it "allows overriding the end_id" do
      expect(worker_instance).to receive(:process_record).exactly(59).times
      worker_instance.perform({"end_id" => 59})
    end

    it "keeps the end_id in the options" do
      expect_any_instance_of(Sidekiq::Job::Setter).to receive(:perform_in).with(1.minute, "start_id" => 101, "end_id" => 159)
      worker_instance.perform({"end_id" => 159})
    end

    it "calls the after process hook" do
      worker_instance.perform(opts)
      record = BackfillableModel.first
      expect(record.processed).to eq true
    end
  end
end
