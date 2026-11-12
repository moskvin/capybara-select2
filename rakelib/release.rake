# frozen_string_literal: true

# Release guard rails for capybara-select (the same as sidekiq-defer's).
#
# Rake loads rakelib/*.rake automatically.
#
# Bundler's `require "bundler/gem_tasks"` already provides:
#   rake build    -> pkg/capybara-select-X.Y.Z.gem
#   rake release  -> build, tag vX.Y.Z, push branch + tag, gem push
# These tasks check the tree, the changelog and the package before anything is pushed.
#
# Typical flow:
#   rake "release:bump[minor]"     # edit Changes.md, commit, push, wait for CI
#   rake release:dry_run           # every check + build + package inspection, no push
#   rake release                   # the real thing (runs release:check first)

require 'json'
require 'net/http'
require 'open3'

module ReleaseTasks
  module_function

  VERSION_FILE = 'lib/capybara-select2/version.rb'
  CHANGELOG = 'Changes.md'
  RELEASE_BRANCH = 'master'
  ALLOWED_FILES = %r{\A(lib/|Changes\.md\z|LICENSE\.txt\z|README\.md\z|[\w-]+\.gemspec\z)}

  def gemspec
    Bundler::GemHelper.instance.gemspec
  end

  def version
    gemspec.version.to_s
  end

  def sh!(*cmd)
    out, status = Open3.capture2e(*cmd)
    abort "FAILED: #{cmd.join(' ')}\n#{out}" unless status.success?
    out.strip
  end

  def check(label)
    ok, detail = yield
    puts "  #{(ok ? 'ok' : 'FAIL').ljust(4)} #{label}#{" (#{detail})" if detail}"
    @failures = (@failures || 0) + (ok ? 0 : 1)
  end

  def failures
    @failures || 0
  end

  def published_versions
    uri = URI("https://rubygems.org/api/v1/versions/#{gemspec.name}.json")
    res = Net::HTTP.get_response(uri)
    return [] if res.is_a?(Net::HTTPNotFound)

    abort "rubygems.org lookup failed: #{res.code}" unless res.is_a?(Net::HTTPSuccess)

    JSON.parse(res.body).map { |v| v['number'] }
  end
end

namespace :release do
  desc 'Verify the tree is releasable: clean, on master, in sync, unpublished version, changelog entry'
  task :check do
    v = ReleaseTasks.version
    puts "Checking #{ReleaseTasks.gemspec.name} #{v}"

    ReleaseTasks.sh!('git', 'fetch', '--quiet', 'origin', '--tags')
    branch = ReleaseTasks.sh!('git', 'rev-parse', '--abbrev-ref', 'HEAD')
    dirty = ReleaseTasks.sh!('git', 'status', '--porcelain', '--untracked-files=all')
    head = ReleaseTasks.sh!('git', 'rev-parse', 'HEAD')
    remote = ReleaseTasks.sh!('git', 'rev-parse', "origin/#{ReleaseTasks::RELEASE_BRANCH}")
    tags = ReleaseTasks.sh!('git', 'tag', '--list', "v#{v}")

    ReleaseTasks.check("on #{ReleaseTasks::RELEASE_BRANCH}") { [branch == ReleaseTasks::RELEASE_BRANCH, branch] }
    ReleaseTasks.check('working tree clean (incl. untracked)') { [dirty.empty?, dirty.lines.first&.strip] }
    ReleaseTasks.check("HEAD == origin/#{ReleaseTasks::RELEASE_BRANCH}") { [head == remote] }
    ReleaseTasks.check("tag v#{v} does not exist yet") { [tags.empty?] }
    ReleaseTasks.check("#{v} not on rubygems.org") { [!ReleaseTasks.published_versions.include?(v)] }
    ReleaseTasks.check("#{ReleaseTasks::CHANGELOG} has a #{v} section") do
      [File.read(ReleaseTasks::CHANGELOG).match?(/^#{Regexp.escape(v)}\s*$/)]
    end
    ReleaseTasks.check('gem files are tracked by git') do
      untracked = ReleaseTasks.gemspec.files.select do |f|
        File.file?(f)
      end - ReleaseTasks.sh!('git', 'ls-files').lines.map(&:strip)
      [untracked.empty?, untracked.first(3).join(', ')]
    end

    abort "release:check failed (#{ReleaseTasks.failures})" if ReleaseTasks.failures.positive?
  end

  desc 'Build the gem and inspect its contents, checksum and loadability'
  task verify: :build do
    v = ReleaseTasks.version
    path = "pkg/#{ReleaseTasks.gemspec.name}-#{v}.gem"
    files = ReleaseTasks.gemspec.files

    ReleaseTasks.check('only expected files packaged') do
      unexpected = files.grep_v(ReleaseTasks::ALLOWED_FILES)
      [unexpected.empty?, unexpected.first(3).join(', ')]
    end
    ReleaseTasks.check('loads in a clean process') do
      out, status = Open3.capture2e(
        Gem.ruby, '-Ilib', '-e',
        'require "capybara-select2"; print Capybara::Select2::VERSION'
      )
      [status.success? && out.end_with?(v), out.lines.last&.strip]
    end

    Rake::Task['build:checksum'].invoke
    puts "  #{path} (#{File.size(path)} bytes), checksum in checksums/"

    abort "release:verify failed (#{ReleaseTasks.failures})" if ReleaseTasks.failures.positive?
  end

  desc 'Run every check, the test suite and a package inspection without pushing anything'
  task dry_run: %w[release:check default release:verify] do
    puts "Dry run OK. `rake release` will tag v#{ReleaseTasks.version} and push it to rubygems.org."
  end

  desc 'Bump the version (part = major|minor|patch) and add a Changes.md section'
  task :bump, [:part] do |_t, args|
    part = args.fetch(:part, 'patch')
    major, minor, patch = ReleaseTasks.version.split('.').map(&:to_i)
    next_version =
      case part
      when 'major' then "#{major + 1}.0.0"
      when 'minor' then "#{major}.#{minor + 1}.0"
      when 'patch' then "#{major}.#{minor}.#{patch + 1}"
      else abort 'part must be major, minor or patch'
      end

    source = File.read(ReleaseTasks::VERSION_FILE)
    File.write(ReleaseTasks::VERSION_FILE, source.sub(/VERSION = ["'][^"']+["']/, "VERSION = \"#{next_version}\""))

    changelog = File.read(ReleaseTasks::CHANGELOG)
    section = "#{next_version}\n---------\n\n- TODO\n\n"
    File.write(ReleaseTasks::CHANGELOG, changelog.sub(/^(?=\d+\.\d+\.\d+\s*$)/, section))

    puts "Bumped to #{next_version}. Fill in #{ReleaseTasks::CHANGELOG}, then commit:"
    puts "  git commit -am 'Release #{next_version}' && git push"
  end
end

# Bundler's `release` pushes straight away. `enhance` would append our checks after its
# push prerequisites, so put them at the front of the list instead.
if Rake::Task.task_defined?('release')
  Rake::Task['release'].prerequisites.unshift('release:check', 'default', 'release:verify')
end
