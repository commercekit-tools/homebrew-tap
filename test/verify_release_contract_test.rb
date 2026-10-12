# frozen_string_literal: true

require "digest"
require "json"
require "minitest/autorun"
require "rubygems/package"
require "stringio"
require "tempfile"
require "zlib"

require_relative "../scripts/verify-release-contract"

class VerifyReleaseContractTest < Minitest::Test
  include CommerceKitReleaseContract

  def setup
    @fixture = Fixture.new
  end

  def test_valid_contract
    assert_equal @fixture.contract.version, verify.fetch(:version)
  end

  def test_version_mismatch
    error = verify_error(formula: @fixture.formula.sub(@fixture.contract.version, "9.9.9"))
    assert_match(/Formula version/, error.message)
  end

  def test_tag_mismatch
    metadata = @fixture.metadata.merge("tag_name" => "cli-v9.9.9")
    error = verify_error(fetches: @fixture.fetches.merge(@fixture.api_url => JSON.generate(metadata)))
    assert_match(/Release tag/, error.message)
  end

  def test_missing_asset
    metadata = @fixture.metadata.merge("assets" => @fixture.metadata.fetch("assets").drop(1))
    error = verify_error(fetches: @fixture.fetches.merge(@fixture.api_url => JSON.generate(metadata)))
    assert_match(/eight-file contract/, error.message)
  end

  def test_wrong_hash
    formula = @fixture.formula.sub(@fixture.contract.archive_sha256.fetch("darwin-arm64"), "0" * 64)
    error = verify_error(formula: formula)
    assert_match(/formula SHA-256/, error.message)
  end

  def test_duplicate_target
    url_line = @fixture.formula.lines.find { |line| line.include?("darwin-arm64") }
    formula = @fixture.formula.sub(url_line, url_line + url_line)
    error = verify_error(formula: formula)
    assert_match(/Duplicate URL mapping/, error.message)
  end

  def test_mutable_latest_url
    formula = @fixture.formula.sub("releases/download/cli-v#{@fixture.interpolation}", "releases/latest/download")
    error = verify_error(formula: formula)
    assert_match(/mutable latest/, error.message)
  end

  def test_windows_asset_reference
    windows = "win" + "dows"
    formula = @fixture.formula.sub("darwin-arm64.tar.gz", "#{windows}-arm64.zip")
    error = verify_error(formula: formula)
    assert_match(/must not reference Windows/, error.message)
  end

  def test_private_repository_url
    private_repository = ["commercekit-tools", "commercekit"].join("/")
    formula = @fixture.formula.sub("commercekit-tools/cli", private_repository)
    error = verify_error(formula: formula)
    assert_match(/private source repository/, error.message)
  end

  def test_malformed_release_manifest
    body = "{"
    metadata = @fixture.metadata_with_asset_hash("release-manifest.json", body)
    fetches = @fixture.fetches.merge(
      @fixture.api_url => JSON.generate(metadata),
      @fixture.manifest_url => body,
    )
    contract = @fixture.contract_with_asset_hash("release-manifest.json", body)
    error = verify_error(fetches: fetches, contract: contract)
    assert_match(/release-manifest.json is malformed JSON/, error.message)
  end

  def test_malformed_sha256sums
    body = "not a checksum\n"
    metadata = @fixture.metadata_with_asset_hash("SHA256SUMS", body)
    fetches = @fixture.fetches.merge(
      @fixture.api_url => JSON.generate(metadata),
      @fixture.checksums_url => body,
    )
    contract = @fixture.contract_with_asset_hash("SHA256SUMS", body)
    error = verify_error(fetches: fetches, contract: contract)
    assert_match(/SHA256SUMS contains a malformed line/, error.message)
  end

  private

  def verify(formula: @fixture.formula, fetches: @fixture.fetches, contract: @fixture.contract)
    with_formula(formula) do |path|
      return Verifier.new(
        formula_path: path,
        fetcher: FakeFetcher.new(fetches),
        contract: contract,
      ).verify!
    end
  end

  def verify_error(**options)
    assert_raises(ContractError) { verify(**options) }
  end

  def with_formula(contents)
    Tempfile.create(["commercekit", ".rb"]) do |file|
      file.write(contents)
      file.flush
      yield file.path
    end
  end

  class FakeFetcher
    def initialize(fetches)
      @fetches = fetches
    end

    def call(url)
      @fetches.fetch(url)
    end
  end

  class Fixture
    attr_reader :contract, :formula, :fetches, :metadata, :api_url, :manifest_url, :checksums_url

    def initialize
      @repository = "commercekit-tools/cli"
      @version = "0.1.0-preview.1"
      @tag = "cli-v#{@version}"
      @build_id = "a" * 40
      @base_url = "https://github.com/#{@repository}/releases/download/#{@tag}"
      @api_url = "https://api.github.com/repos/#{@repository}/releases/tags/#{@tag}"
      @interpolation = '#{version}'

      archives = target_names.to_h { |target| [target, build_archive(target)] }
      archive_sha256 = archives.transform_values { |body| Digest::SHA256.hexdigest(body) }
      manifest = build_manifest(archive_sha256)
      checksums = build_checksums(archive_sha256, manifest)
      release_asset_sha256 = {
        "release-manifest.json" => Digest::SHA256.hexdigest(manifest),
        "SHA256SUMS" => Digest::SHA256.hexdigest(checksums),
      }

      @contract = CommerceKitReleaseContract::Contract.new(
        repository: @repository,
        version: @version,
        tag: @tag,
        build_id: @build_id,
        archive_sha256: archive_sha256,
        release_asset_sha256: release_asset_sha256,
      )
      @manifest_url = "#{@base_url}/release-manifest.json"
      @checksums_url = "#{@base_url}/SHA256SUMS"
      @metadata = build_metadata(archive_sha256, release_asset_sha256)
      @formula = build_formula(archive_sha256)
      @fetches = {
        @api_url => JSON.generate(@metadata),
        @manifest_url => manifest,
        @checksums_url => checksums,
      }.merge(archives.to_h { |target, body| ["#{@base_url}/#{filename(target)}", body] })
    end

    def interpolation
      @interpolation
    end

    def contract_with_asset_hash(name, body)
      CommerceKitReleaseContract::Contract.new(
        repository: contract.repository,
        version: contract.version,
        tag: contract.tag,
        build_id: contract.build_id,
        archive_sha256: contract.archive_sha256,
        release_asset_sha256: contract.release_asset_sha256.merge(name => Digest::SHA256.hexdigest(body)),
      )
    end

    def metadata_with_asset_hash(name, body)
      metadata.merge(
        "assets" => metadata.fetch("assets").map do |asset|
          next asset unless asset.fetch("name") == name

          asset.merge("digest" => "sha256:#{Digest::SHA256.hexdigest(body)}")
        end,
      )
    end

    private

    def target_names
      %w[darwin-arm64 darwin-x64 linux-arm64 linux-x64 windows-arm64 windows-x64]
    end

    def homebrew_target_names
      %w[darwin-arm64 darwin-x64 linux-arm64 linux-x64]
    end

    def filename(target)
      extension = target.start_with?("windows-") ? "zip" : "tar.gz"
      "commercekit-v#{@version}-#{target}.#{extension}"
    end

    def build_archive(target)
      buffer = StringIO.new("".b)
      Zlib::GzipWriter.wrap(buffer) do |gzip|
        Gem::Package::TarWriter.new(gzip) do |tar|
          add_file(tar, "LICENSE", 0o644, "MIT\n")
          add_file(tar, "README.txt", 0o644, "#{target}\n")
          add_file(tar, "THIRD_PARTY_NOTICES", 0o644, "Notices\n")
          add_file(tar, "commercekit", 0o755, "binary\n")
        end
      end
      buffer.string
    end

    def add_file(tar, name, mode, contents)
      tar.add_file_simple(name, mode, contents.bytesize) { |io| io.write(contents) }
    end

    def build_manifest(archive_sha256)
      JSON.generate(
        "schemaVersion" => 1,
        "product" => "commercekit-cli",
        "cliVersion" => @version,
        "buildId" => @build_id,
        "channel" => "preview",
        "unsigned" => true,
        "artifacts" => archive_sha256.map do |target, sha256|
          {
            "target" => target,
            "filename" => filename(target),
            "sha256" => sha256,
          }
        end,
      )
    end

    def build_checksums(archive_sha256, manifest)
      lines = archive_sha256.map { |target, sha256| "#{sha256}  #{filename(target)}" }
      lines << "#{Digest::SHA256.hexdigest(manifest)}  release-manifest.json"
      "#{lines.join("\n")}\n"
    end

    def build_metadata(archive_sha256, release_asset_sha256)
      hashes = archive_sha256.to_h { |target, sha256| [filename(target), sha256] }.merge(release_asset_sha256)
      {
        "tag_name" => @tag,
        "draft" => false,
        "prerelease" => true,
        "published_at" => "2026-01-01T00:00:00Z",
        "assets" => hashes.map do |name, sha256|
          {
            "name" => name,
            "digest" => "sha256:#{sha256}",
            "browser_download_url" => "#{@base_url}/#{name}",
          }
        end,
      }
    end

    def build_formula(archive_sha256)
      blocks = homebrew_target_names.map do |target|
        os, architecture = target.split("-", 2)
        os_block = os == "darwin" ? "macos" : "linux"
        arch_block = architecture == "arm64" ? "arm" : "intel"
        [os_block, arch_block, target]
      end.group_by(&:first)

      body = blocks.map do |os_block, entries|
        nested = entries.map do |_, arch_block, target|
          <<~RUBY
              on_#{arch_block} do
                url "https://github.com/#{@repository}/releases/download/cli-v#{@interpolation}/commercekit-v#{@interpolation}-#{target}.tar.gz"
                sha256 "#{archive_sha256.fetch(target)}"
              end
          RUBY
        end.join("\n")
        "  on_#{os_block} do\n#{nested}  end"
      end.join("\n\n")

      <<~RUBY
        class Commercekit < Formula
          version "#{@version}"

        #{body}
        end
      RUBY
    end
  end
end
