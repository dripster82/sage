# frozen_string_literal: true

require 'net/http'
require 'json'

class OpenrouterService
  BASE_URL = 'https://openrouter.ai/api/v1'
  CREDITS_ENDPOINT = "#{BASE_URL}/credits"

  def self.credits
    new.credits
  end

  def credits
    return nil unless api_key.present?

    begin
      uri = URI(CREDITS_ENDPOINT)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{api_key}"
      request['Content-Type'] = 'application/json'

      response = http.request(request)

      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)
        total_credits = data.dig('data', 'total_credits')&.to_f || 0.0
        total_usage = data.dig('data', 'total_usage')&.to_f || 0.0
        total_credits - total_usage
      else
        Rails.logger.error "OpenRouter API error: #{response.code} - #{response.body}"
        nil
      end
    rescue => e
      Rails.logger.error "Failed to fetch OpenRouter credits: #{e.message}"
      nil
    end
  end

  private

  def api_key
    ENV.fetch('OPENROUTER_API_KEY', nil)
  end
end