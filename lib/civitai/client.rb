# frozen_string_literal: true

require "http"
require "json"
require "fileutils"

module Civitai
  # Ruby client for the CivitAI REST API.
  #
  # @example
  #   client = Civitai::Client.new(api_key: "your_key")
  #   client.model(12345)
  #   client.search("mecha", type: "LORA", base_model: "SDXL 1.0")
  #   client.download(version_id: 67890, output: "/path/to/models/")
  #
  class Client
    attr_reader :api_key

    # @param api_key [String, nil] CivitAI API key (optional, enables higher rate limits)
    # @param timeout [Integer] HTTP timeout in seconds
    def initialize(api_key: nil, timeout: 30)
      @api_key = api_key || ENV["CIVITAI_API_KEY"]
      @timeout = timeout
    end

    # ----------------------------------------------------------------
    # Model queries
    # ----------------------------------------------------------------

    # Fetch a model by ID.
    # @param model_id [Integer]
    # @return [Hash]
    def model(model_id)
      get("/models/#{model_id}")
    end

    # Fetch a model version by ID.
    # @param version_id [Integer]
    # @return [Hash]
    def model_version(version_id)
      get("/model-versions/#{version_id}")
    end

    # Fetch a model version by file SHA256 hash.
    # @param hash [String] SHA256 hash
    # @return [Hash]
    def by_hash(hash)
      get("/model-versions/by-hash/#{hash}")
    end

    # ----------------------------------------------------------------
    # Search
    # ----------------------------------------------------------------

    # Search CivitAI models.
    #
    # @param query [String, nil] search query
    # @param type [String, nil] model type: Checkpoint, LORA, TextualInversion, etc.
    # @param base_model [String, nil] base model: "SD 1.5", "SDXL 1.0", "Pony", etc.
    # @param sort [String] sort order: "Highest Rated", "Most Downloaded", "Newest"
    # @param limit [Integer] max results (1-100)
    # @param period [String, nil] time period: "Day", "Week", "Month", "Year", "AllTime"
    # @param nsfw [Boolean, nil] nil = include all, true = only nsfw, false = exclude nsfw
    # @param tag [String, nil] filter by tag
    # @param username [String, nil] filter by creator
    # @param page [Integer, nil] page number
    # @return [Hash] with "items" array and "metadata" pagination
    def search(
      query = nil,
      type: nil,
      base_model: nil,
      sort: "Most Downloaded",
      limit: 20,
      period: nil,
      nsfw: nil,
      tag: nil,
      username: nil,
      page: nil
    )
      params = build_search_params(
        query: query, type: type, base_model: base_model,
        sort: sort, limit: limit, period: period, nsfw: nsfw,
        tag: tag, username: username, page: page
      )

      has_filters = !type.nil? || !base_model.nil? || !tag.nil?
      result = get("/models", **params)
      filter_results(result, query, has_filters, limit)
    end

    # ----------------------------------------------------------------
    # Download
    # ----------------------------------------------------------------

    # Download a model file.
    #
    # @param version_id [Integer, nil] model version ID
    # @param model_id [Integer, nil] model ID (downloads latest version)
    # @param output [String] output directory or file path
    # @param on_progress [Proc, nil] callback(downloaded_bytes, total_bytes)
    # @return [String] path to downloaded file
    def download(version_id: nil, model_id: nil, output: ".", on_progress: nil)
      raise ArgumentError, "Provide version_id or model_id" unless version_id || model_id

      unless version_id
        m = model(model_id)
        version_id = m.dig("modelVersions", 0, "id")
        raise NotFoundError, "No versions found for model #{model_id}" unless version_id
      end

      url = "#{DOWNLOAD_BASE}/#{version_id}"
      download_file(url, output, on_progress: on_progress)
    end

    private

    def http
      client = HTTP
        .headers("Accept" => "application/json")
        .headers("User-Agent" => "civitai-ruby/#{Civitai::VERSION}")
        .timeout(@timeout)
        .follow(max_hops: 5)

      client = client.auth("Bearer #{@api_key}") if @api_key
      client
    end

    def get(path, **params)
      url = "#{API_BASE}#{path}"
      response = http.get(url, params: params)

      case response.status.to_i
      when 200
        JSON.parse(response.body.to_s)
      when 404
        raise NotFoundError, "Not found: #{path}"
      when 429
        raise RateLimitError, "CivitAI rate limit exceeded"
      else
        raise APIError, "CivitAI API error: #{response.status}"
      end
    end

    def build_search_params(query:, type:, base_model:, sort:, limit:, period:, nsfw:, tag:, username:, page:)
      params = {limit: [limit, 100].min, sort: sort}
      params[:nsfw] = nsfw.nil? ? "true" : nsfw.to_s

      has_filters = !type.nil? || !base_model.nil? || !tag.nil?
      params[:query] = query if query && !has_filters
      params[:types] = type if type
      params[:baseModels] = base_model if base_model
      params[:period] = period if period
      params[:tag] = tag if tag
      params[:username] = username if username
      params[:page] = page if page && page > 1
      params[:limit] = 100 if query && has_filters

      params
    end

    def filter_results(result, query, has_filters, limit)
      return result unless query && has_filters

      q_lower = query.downcase
      items = (result["items"] || []).select { |m| m["name"]&.downcase&.include?(q_lower) }
      result.merge("items" => items.first(limit))
    end

    def download_file(url, output, on_progress: nil)
      output_path = File.directory?(output) ? output : File.dirname(output)
      FileUtils.mkdir_p(output_path)

      dl_client = HTTP
        .headers("User-Agent" => "civitai-ruby/#{Civitai::VERSION}")
        .follow(max_hops: 5)
      dl_client = dl_client.auth("Bearer #{@api_key}") if @api_key

      response = dl_client.get(url)

      # Extract filename from Content-Disposition
      cd = response.headers["Content-Disposition"]
      filename = if cd && cd =~ /filename="?([^";\s]+)"?/
        $1
      else
        "model_#{Time.now.to_i}.safetensors"
      end

      dest = File.directory?(output) ? File.join(output, filename) : output
      total = response.headers["Content-Length"]&.to_i || 0
      downloaded = 0

      File.open(dest, "wb") do |file|
        response.body.each do |chunk|
          file.write(chunk)
          downloaded += chunk.bytesize
          on_progress&.call(downloaded, total)
        end
      end

      dest
    end
  end
end
