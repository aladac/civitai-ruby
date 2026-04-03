# frozen_string_literal: true

require_relative "lib/civitai/version"

Gem::Specification.new do |spec|
  spec.name = "civitai-ruby"
  spec.version = Civitai::VERSION
  spec.authors = ["aladac"]
  spec.email = ["aladac@saiden.dev"]

  spec.summary = "Ruby client for the CivitAI API"
  spec.description = "Search, browse, and download AI models from CivitAI. " \
    "Supports model lookup by ID/hash, search with filters, and streaming downloads with resume."
  spec.homepage = "https://github.com/aladac/civitai-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir["lib/**/*", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "http", "~> 5.0"
end
