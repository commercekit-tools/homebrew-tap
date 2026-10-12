#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "json"
require "net/http"
require "rubygems/package"
require "stringio"
require "uri"
require "zlib"

module CommerceKitReleaseContract
  class ContractError < StandardError; end

  Contract = Struct.new(
    :repository,
    :version,
    :tag,
    :build_id,
    :archive_sha256,
    :release_asset_sha256,
    keyword_init: true,
  )

  DEFAULT_CONTRACT = Contract.new(
    repository: "commercekit-tools/cli",
    version: "0.1.0-preview.1",
    tag: "cli-v0.1.0-preview.1",
    build_id: "c3277e64a322b5057058fc74f76bb83ea7ff8d06",
    archive_sha256: {
      "darwin-arm64" => "097704b2750b906daf87f6309ca96a825d4058fd3fce85ad7523561db69d82bf",
      "darwin-x64" => "d8307276978b745bf3d86eb1b6d164f23b304cc2c82a75e301f7e4fead2927de",
      "linux-arm64" => "914d5acad10351e21f426b93b2c95f97aa8a9afc1284a550343aead09ff86fb9",
      "linux-x64" => "d01dd1bc45b39125ddc642b84163ceb24239a6a3ff9c80f69efe2e4939187d0b",
      "windows-arm64" => "e13df10cc9b95c80a41b4d42dd180f4382bd91a7c0be8659ce77bb313b9d8bdf",
      "windows-x64" => "a2d050a4a688c7d5e7b5245193148da7faa8a979c2003c09886284030da27d4e",
    }.freeze,
    release_asset_sha256: {
      "release-manifest.json" => "c4c776b0456a34859fb782d7b9c6bc7545cab75235d646da044189499ccf52b8",
      "SHA256SUMS" => "2231343f1dc44538a99a29324c6247325ba497c4bbb9057fb8f4059233347238",
    }.freeze,
  ).freeze

  HOMEBREW_TARGETS = %w[darwin-arm64 darwin-x64 linux-arm64 linux-x64].freeze
  ARCHIVE_ENTRIES = %w[LICENSE README.txt THIRD_PARTY_NOTICES commercekit].freeze

  class HttpFetcher
    MAX_REDIRECTS = 5

    def call(url)
      uri = URI(url)

      MAX_REDIRECTS.times do
        request = Net::HTTP::Get.new(uri)
        request["Accept"] = "application/vnd.github+json"
        request["User-Agent"] = "commercekit-homebrew-release-verifier"

        response = Net::HTTP.start(
          uri.hostname,
          uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: 20,
          read_timeout: 180,
        ) { |http| http.request(request) }

        case response
        when Net::HTTPSuccess
          return response.body
        when Net::HTTPRedirection
          location = response["location"]
          raise ContractError, "Redirect from #{uri} did not include a location." if location.nil?

          uri = URI.join(uri, location)
        else
          raise ContractError, "GET #{uri} failed with HTTP #{response.code}."
        end
      end

      raise ContractError, "GET #{url} exceeded #{MAX_REDIRECTS} redirects."
    end
  end

  class FormulaParser
    Target = Struct.new(:name, :url, :sha256, keyword_init: true)

    attr_reader :source, :version, :targets

    def initialize(path)
      @source = File.read(path)
      @version = parse_version
      @targets = parse_targets
    end

    private

    def parse_version
      versions = source.scan(/^\s*version "([^"]+)"\s*$/).flatten
      raise ContractError, "Formula must declare exactly one version." unless versions.length == 1

      versions.first
    end

    def parse_targets
      platform_stack = []
      parsed = {}

      source.each_line do |line|
        stripped = line.strip

        if (match = stripped.match(/\Aon_(macos|linux|arm|intel) do\z/))
          platform_stack << match[1]
          next
        end

        if stripped == "end" && !platform_stack.empty?
          platform_stack.pop
          next
        end

        target_name = target_name_for(platform_stack)
        next if target_name.nil?

        if (match = stripped.match(/\Aurl "([^"]+)"\z/))
          target = parsed[target_name] ||= Target.new(name: target_name)
          raise ContractError, "Duplicate URL mapping for #{target_name}." unless target.url.nil?

          target.url = match[1].gsub('#{version}', version)
        elsif (match = stripped.match(/\Asha256 "([0-9a-f]{64})"\z/))
          target = parsed[target_name] ||= Target.new(name: target_name)
          raise ContractError, "Duplicate SHA-256 mapping for #{target_name}." unless target.sha256.nil?

          target.sha256 = match[1]
        end
      end

      parsed.each_value do |target|
        raise ContractError, "#{target.name} is missing its URL." if target.url.nil?
        raise ContractError, "#{target.name} is missing its SHA-256." if target.sha256.nil?
      end

      parsed
    end

    def target_name_for(stack)
      return nil unless stack.length == 2

      os = { "macos" => "darwin", "linux" => "linux" }[stack[0]]
      architecture = { "arm" => "arm64", "intel" => "x64" }[stack[1]]
      return nil if os.nil? || architecture.nil?

      "#{os}-#{architecture}"
    end
  end

  class Verifier
    attr_reader :formula_path, :fetcher, :contract, :verify_archives

    def initialize(formula_path:, fetcher: HttpFetcher.new, contract: DEFAULT_CONTRACT, verify_archives: true)
      @formula_path = formula_path
      @fetcher = fetcher
      @contract = contract
      @verify_archives = verify_archives
    end

    def verify!
      formula = FormulaParser.new(formula_path)
      verify_formula(formula)

      metadata = parse_json(fetch(release_api_url), "release metadata")
      assets = verify_release_metadata(metadata)
      manifest_body = fetch(asset_url(assets, "release-manifest.json"))
      checksums_body = fetch(asset_url(assets, "SHA256SUMS"))
      manifest = verify_manifest(manifest_body)
      checksums = verify_checksums(checksums_body, manifest_body)
      verify_formula_parity(formula, manifest, checksums, assets)
      verify_archive_contents(formula) if verify_archives

      {
        version: contract.version,
        tag: contract.tag,
        build_id: contract.build_id,
        formula_targets: formula.targets.keys.sort,
        archive_entries: ARCHIVE_ENTRIES,
      }
    end

    private

    def verify_formula(formula)
      assert(formula.version == contract.version, "Formula version must be #{contract.version}.")
      assert(formula.targets.keys.sort == HOMEBREW_TARGETS, "Formula must map each Homebrew target exactly once.")

      lowered = formula.source.downcase
      assert(!lowered.include?("releases/latest"), "Formula must not use a mutable latest release URL.")
      assert(!lowered.include?("download/latest"), "Formula must not use a mutable latest download URL.")
      assert(!lowered.include?("windows-"), "Formula must not reference Windows assets.")

      private_path = ["commercekit-tools", "commercekit"].join("/")
      assert(!lowered.include?("github.com/#{private_path}"), "Formula must not reference the private source repository.")

      formula.targets.each do |target_name, target|
        filename = archive_filename(target_name)
        expected_url = "#{release_download_base}/#{filename}"
        assert(target.url == expected_url, "#{target_name} URL must be the immutable versioned release URL.")
        assert(target.sha256 == contract.archive_sha256.fetch(target_name), "#{target_name} formula SHA-256 is incorrect.")
      end
    end

    def verify_release_metadata(metadata)
      assert(metadata["tag_name"] == contract.tag, "Release tag must be #{contract.tag}.")
      assert(metadata["draft"] == false, "Release must not be a draft.")
      assert(metadata["prerelease"] == true, "Release must be a prerelease.")
      assert(!metadata["published_at"].to_s.empty?, "Release must be published.")

      assets = metadata.fetch("assets")
      names = assets.map { |asset| asset.fetch("name") }
      assert(names.uniq.length == names.length, "Release contains duplicate asset names.")
      assert(names.sort == expected_release_asset_names.sort, "Release assets do not match the expected eight-file contract.")

      expected_release_hashes.each do |name, sha256|
        asset = assets.find { |candidate| candidate["name"] == name }
        digest = asset["digest"]
        assert(digest.nil? || digest == "sha256:#{sha256}", "Release metadata digest is incorrect for #{name}.")
      end

      assets
    end

    def verify_manifest(body)
      expected_sha256 = contract.release_asset_sha256.fetch("release-manifest.json")
      assert(Digest::SHA256.hexdigest(body) == expected_sha256, "release-manifest.json SHA-256 is incorrect.")

      manifest = parse_json(body, "release-manifest.json")
      assert(manifest["schemaVersion"] == 1, "Release manifest schema version must be 1.")
      assert(manifest["product"] == "commercekit-cli", "Release manifest product is incorrect.")
      assert(manifest["cliVersion"] == contract.version, "Release manifest version is incorrect.")
      assert(manifest["buildId"] == contract.build_id, "Release manifest source build ID is incorrect.")
      assert(manifest["channel"] == "preview", "Release manifest channel must be preview.")
      assert(manifest["unsigned"] == true, "Release manifest must disclose unsigned artifacts.")

      artifacts = manifest.fetch("artifacts")
      targets = artifacts.map { |artifact| artifact.fetch("target") }
      filenames = artifacts.map { |artifact| artifact.fetch("filename") }
      assert(targets.uniq.length == targets.length, "Release manifest contains duplicate targets.")
      assert(filenames.uniq.length == filenames.length, "Release manifest contains duplicate filenames.")
      assert(targets.sort == contract.archive_sha256.keys.sort, "Release manifest target set is incorrect.")

      artifacts.each do |artifact|
        target_name = artifact.fetch("target")
        assert(artifact.fetch("filename") == archive_filename(target_name), "Manifest filename is incorrect for #{target_name}.")
        assert(artifact.fetch("sha256") == contract.archive_sha256.fetch(target_name), "Manifest SHA-256 is incorrect for #{target_name}.")
      end

      manifest
    end

    def verify_checksums(body, manifest_body)
      expected_sha256 = contract.release_asset_sha256.fetch("SHA256SUMS")
      assert(Digest::SHA256.hexdigest(body) == expected_sha256, "SHA256SUMS file SHA-256 is incorrect.")

      checksums = {}
      body.each_line do |line|
        match = line.chomp.match(/\A([0-9a-f]{64})  ([^\r\n]+)\z/)
        raise ContractError, "SHA256SUMS contains a malformed line." if match.nil?
        raise ContractError, "SHA256SUMS contains duplicate filenames." if checksums.key?(match[2])

        checksums[match[2]] = match[1]
      end

      expected_names = contract.archive_sha256.keys.map { |target| archive_filename(target) } + ["release-manifest.json"]
      assert(checksums.keys.sort == expected_names.sort, "SHA256SUMS filename set is incorrect.")

      contract.archive_sha256.each do |target_name, sha256|
        assert(checksums.fetch(archive_filename(target_name)) == sha256, "SHA256SUMS is incorrect for #{target_name}.")
      end
      assert(
        checksums.fetch("release-manifest.json") == Digest::SHA256.hexdigest(manifest_body),
        "SHA256SUMS is incorrect for release-manifest.json.",
      )

      checksums
    end

    def verify_formula_parity(formula, manifest, checksums, assets)
      manifest_by_target = manifest.fetch("artifacts").to_h { |artifact| [artifact.fetch("target"), artifact] }

      formula.targets.each do |target_name, target|
        artifact = manifest_by_target.fetch(target_name)
        filename = artifact.fetch("filename")
        assert(target.sha256 == artifact.fetch("sha256"), "Formula and manifest hashes differ for #{target_name}.")
        assert(target.sha256 == checksums.fetch(filename), "Formula and SHA256SUMS hashes differ for #{target_name}.")
        assert(target.url == asset_url(assets, filename), "Formula and release metadata URLs differ for #{target_name}.")
      end
    end

    def verify_archive_contents(formula)
      formula.targets.each do |target_name, target|
        body = fetch(target.url)
        assert(Digest::SHA256.hexdigest(body) == target.sha256, "Downloaded archive SHA-256 is incorrect for #{target_name}.")

        entries = []
        executable = false
        Zlib::GzipReader.wrap(StringIO.new(body)) do |gzip|
          Gem::Package::TarReader.new(gzip) do |tar|
            tar.each do |entry|
              entries << entry.full_name
              executable = (entry.header.mode & 0o111).positive? if entry.full_name == "commercekit"
            end
          end
        end

        assert(entries.sort == ARCHIVE_ENTRIES.sort, "#{target_name} archive entries are incorrect.")
        assert(executable, "#{target_name} archive does not mark commercekit executable.")
      rescue Zlib::GzipFile::Error, Gem::Package::TarInvalidError => e
        raise ContractError, "#{target_name} archive is malformed: #{e.message}"
      end
    end

    def parse_json(body, label)
      JSON.parse(body)
    rescue JSON::ParserError => e
      raise ContractError, "#{label} is malformed JSON: #{e.message}"
    end

    def fetch(url)
      fetcher.call(url)
    rescue ContractError
      raise
    rescue StandardError => e
      raise ContractError, "Failed to fetch #{url}: #{e.message}"
    end

    def asset_url(assets, name)
      asset = assets.find { |candidate| candidate["name"] == name }
      raise ContractError, "Release asset #{name} is missing." if asset.nil?

      asset.fetch("browser_download_url")
    end

    def release_api_url
      "https://api.github.com/repos/#{contract.repository}/releases/tags/#{contract.tag}"
    end

    def release_download_base
      "https://github.com/#{contract.repository}/releases/download/#{contract.tag}"
    end

    def archive_filename(target_name)
      extension = target_name.start_with?("windows-") ? "zip" : "tar.gz"
      "commercekit-v#{contract.version}-#{target_name}.#{extension}"
    end

    def expected_release_hashes
      contract.archive_sha256.to_h { |target, sha256| [archive_filename(target), sha256] }
        .merge(contract.release_asset_sha256)
    end

    def expected_release_asset_names
      expected_release_hashes.keys
    end

    def assert(condition, message)
      raise ContractError, message unless condition
    end
  end
end

if $PROGRAM_NAME == __FILE__
  formula_path = File.expand_path("../Formula/commercekit.rb", __dir__)

  begin
    result = CommerceKitReleaseContract::Verifier.new(formula_path: formula_path).verify!
    puts "Verified CommerceKit CLI #{result.fetch(:version)} (#{result.fetch(:tag)})."
    puts "Source build: #{result.fetch(:build_id)}"
    puts "Formula targets: #{result.fetch(:formula_targets).join(', ')}"
    puts "Archive entries: #{result.fetch(:archive_entries).join(', ')}"
  rescue CommerceKitReleaseContract::ContractError => e
    warn "Release contract verification failed: #{e.message}"
    exit 1
  end
end
