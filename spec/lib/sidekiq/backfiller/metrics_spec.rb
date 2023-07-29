RSpec.describe Sidekiq::Backfiller::Metrics do
  subject(:metrics) { Sidekiq::Backfiller::Metrics.new }

  describe ".increment_processed" do
    it "increments the counter" do
      subject.increment_processed
      expect(subject.processed).to eq(1)
    end
  end

  describe ".increment_errors" do
    it "increments the error count" do
      subject.increment_errors
      expect(subject.errors).to eq(1)
    end
  end

  describe ".to_h" do
    it "returns a hash representation" do
      subject.processed = 5
      subject.errors = 10
      expect(subject.to_h).to include("processed" => 5, "errors" => 10)
    end
  end
end
