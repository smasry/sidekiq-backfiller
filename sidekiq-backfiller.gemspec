Gem::Specification.new do |spec|
  spec.name = "sidekiq-backfiller"
  spec.version = File.read(File.expand_path("../VERSION", __FILE__)).strip
  spec.authors = ["Samer Masry"]
  spec.email = ["samer.masry@gmail.com"]

  spec.summary = "Sidekiq plugin for backfilling data"
  spec.homepage = "https://github.com/smasry/sidekiq-backfiller"
  spec.license = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  ignore_files = %w[
    .
    Gemfile
    Gemfile.lock
    Rakefile
    bin/
    gemfiles/
    spec/
  ]
  spec.files = Dir.chdir(File.expand_path("..", __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| ignore_files.any? { |path| f.start_with?(path) } }
  end

  spec.require_paths = ["lib"]

  spec.add_dependency "sidekiq"
  spec.add_dependency "activesupport", ">= 6.0.0"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "activerecord", ">= 6.0.0"
  spec.add_development_dependency "activerecord-nulldb-adapter", "~> 0.9"
  spec.add_development_dependency "sqlite3", "~> 1.6"
  spec.add_development_dependency "fakeredis", "~> 0.9"
  spec.add_development_dependency "standardrb", "~> 1.0"
  spec.required_ruby_version = ">= 2.7"
end
