lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "active_record/full_text_search/version"

Gem::Specification.new do |spec|
  spec.name = "activerecord-full_text_search"
  spec.version = ActiveRecord::FullTextSearch::VERSION
  spec.authors = ["Codeur SAS"]
  spec.email = ["dev@codeur.com"]

  spec.summary = "Integrate PostgreSQL's FTS condigs with Rails"
  spec.homepage = "https://github.com/codeur/activerecord-full_text_search"
  spec.license = "MIT"

  spec.metadata = {
    "bug_tracker_uri" => "https://github.com/codeur/activerecord-full_text_search/issues",
    "changelog_uri" => "https://github.com/codeur/activerecord-full_text_search/blob/master/CHANGELOG.md",
    "pgp_keys_uri" => "https://keybase.io/codeur/pgp_keys.asc",
    "signatures_uri" => "https://keybase.pub/codeur/gems/"
  }

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.required_ruby_version = ">= 2.2.2"

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "pg"
  spec.add_dependency "activerecord", ">= 7.2.0"
  spec.add_dependency "activesupport"
end
