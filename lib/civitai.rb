# frozen_string_literal: true

# frozen_string_literal: true

require_relative "civitai/version"
require_relative "civitai/client"

module Civitai
  API_BASE = "https://civitai.com/api/v1"
  DOWNLOAD_BASE = "https://civitai.com/api/download/models"

  class Error < StandardError; end
  class NotFoundError < Error; end
  class APIError < Error; end
  class RateLimitError < Error; end
end
