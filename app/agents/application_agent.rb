require 'json'

class ApplicationAgent
  # Base class for all AI agents using OpenAI

  def initialize
    @client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
  end

  protected

  def call_openai(prompt, temperature: 0.1, max_tokens: 32768, model: "gpt-4.1-nano-2025-04-14")
    log_debug "Making OpenAI API call with model: #{model}"
    log_debug "Prompt length: #{prompt.length} characters"

    response = @client.chat(
      parameters: {
        model: model,
        messages: [{ role: "user", content: prompt }],
        temperature: temperature,
        max_tokens: max_tokens
      }
    )

    if response.nil?
      log_error "OpenAI API returned nil response"
      return OpenStruct.new(content: nil)
    end

    # Check for OpenAI API errors
    if response["error"].present?
      error_info = response["error"]
      log_error "OpenAI API returned error: #{error_info}"
      log_error "Error type: #{error_info['type'] if error_info.is_a?(Hash)}"
      log_error "Error message: #{error_info['message'] if error_info.is_a?(Hash)}"
      return OpenStruct.new(content: nil)
    end

    # Check for choices array
    unless response["choices"].is_a?(Array) && response["choices"].any?
      log_error "OpenAI API response missing choices array"
      log_error "Full response: #{response.inspect}"
      return OpenStruct.new(content: nil)
    end

    content = response.dig("choices", 0, "message", "content")
    log_debug "Received response: #{content&.length || 0} characters"

    if content.nil?
      log_error "OpenAI API returned response without content"
      log_error "Response structure: #{response.keys.inspect}"
      log_error "First choice: #{response.dig('choices', 0)&.keys&.inspect}"
      log_error "First choice message: #{response.dig('choices', 0, 'message')&.inspect}"
    end

    OpenStruct.new(content: content)

  rescue => e
    log_error "OpenAI API call failed: #{e.class}: #{e.message}"
    log_error e.backtrace[0..5].join("\n") if e.backtrace
    raise
  end

  private

  def log_info(message)
    Rails.logger.info "[#{self.class.name}] #{message}"
  end

  def log_error(message)
    Rails.logger.error "[#{self.class.name}] #{message}"
  end

  def log_debug(message)
    Rails.logger.debug "[#{self.class.name}] #{message}"
  end
end
