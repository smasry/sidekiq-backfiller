# frozen_string_literal: true

require "sidekiq"

module Sidekiq::Backfiller
  VERSION = File.read(File.expand_path("../../../VERSION", __dir__)).chomp.freeze
end
