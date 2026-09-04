require "cgi"
require "net/http"

module Ai
  class ReviewRewrite
    BASE = "https://generativelanguage.googleapis.com/v1beta".freeze

    PROMPTS_DIR = Rails.root.join("app/services/ai/prompts").freeze

    TIMEOUT_S = 20
    MAX_NOTES_CHARS = 1_500

    def self.configured? = Rails.application.config.settings.gemini.api_key.present?

    def initialize(api_key: Rails.application.config.settings.gemini.api_key,
                   model: Rails.application.config.settings.gemini.model)
      @api_key = api_key
      @model = model
    end

    def call(notes:, place_type:, locale: I18n.locale)
      prompt = prompt_for(notes.to_s.strip.first(MAX_NOTES_CHARS), place_type.to_s, locale)

      review_from(perform({ contents: [ { role: "user", parts: [ { text: prompt } ] } ] }))
    end

    private

    def prompt_for(notes, place_type, locale)
      template(locale)
        .sub("{{place_type}}") { place_type }
        .sub("{{review_notes}}") { notes }
    end

    def template(locale)
      supported = I18n.available_locales.include?(locale.to_sym) ? locale : I18n.default_locale
      PROMPTS_DIR.join("review_rewrite.#{supported}.txt").read
    end

    def review_from(payload)
      blocked = payload.dig("promptFeedback", "blockReason")
      raise GeminiError, "Gemini từ chối prompt: #{blocked}" if blocked.present?

      parts = Array(payload.dig("candidates", 0, "content", "parts"))
      review = parts.reject { |part| part["thought"] }.filter_map { |part| part["text"] }.join.strip
      raise GeminiError, "Gemini trả về nội dung rỗng" if review.blank?

      review
    end

    def perform(body)
      uri = URI("#{BASE}/models/#{CGI.escape(@model)}:generateContent")
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["x-goog-api-key"] = @api_key
      request.body = body.to_json

      response = Net::HTTP.start(uri.hostname, uri.port,
                                 use_ssl: true, open_timeout: TIMEOUT_S, read_timeout: TIMEOUT_S) do |http|
        http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.warn("[ai.gemini] #{response.code} model=#{@model}")
        raise GeminiError.new("Gemini trả về #{response.code}", status: response.code.to_i)
      end

      JSON.parse(response.body)
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      raise GeminiError, "Gemini timeout sau #{TIMEOUT_S}s: #{e.class}"
    end
  end
end
