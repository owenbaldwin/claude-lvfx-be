class SluglineExtractorAgent < ApplicationAgent
  def extract_sluglines(script_text)
    Rails.logger.info "[SluglineExtractorAgent] Starting slugline extraction"
    Rails.logger.info "[SluglineExtractorAgent] Script length: #{script_text.length} characters"

    prompt = build_slugline_prompt(script_text)

    Rails.logger.info "[SluglineExtractorAgent] Making OpenAI API call with GPT-4.1 nano"
    Rails.logger.info "[SluglineExtractorAgent] Prompt length: #{prompt.length} characters"

    response = call_openai(prompt)

    if response && !response.empty?
      # Extract content from OpenStruct response
      response_content = response.respond_to?(:content) ? response.content : response.to_s

      if response_content && !response_content.empty?
        sluglines = parse_sluglines_response(response_content)
        Rails.logger.info "[SluglineExtractorAgent] Found #{sluglines.length} sluglines"
        return sluglines
      else
        Rails.logger.error "[SluglineExtractorAgent] OpenAI returned empty content"
        return []
      end
    else
      Rails.logger.error "[SluglineExtractorAgent] OpenAI returned empty response"
      return []
    end
  end

  private

  def build_slugline_prompt(script_text)
    <<~PROMPT
      You are a professional script analyst. Extract all scene sluglines (scene headers) from this screenplay text.

      A slugline typically follows this format:
      - INT. LOCATION - TIME
      - EXT. LOCATION - TIME
      - Examples: "INT. BEDROOM - NIGHT", "EXT. PARK - DAY"

      Please extract ONLY the sluglines and return them as a JSON array of objects with this format:
      [
        {"text": "INT. BEDROOM - NIGHT", "line_number": 1},
        {"text": "EXT. PARK - DAY", "line_number": 15}
      ]

      If no sluglines are found, return an empty array: []

      Script text:
      #{script_text}
    PROMPT
  end

  def parse_sluglines_response(response)
    begin
      # Try to parse as JSON
      parsed = JSON.parse(response)

      if parsed.is_a?(Array)
        return parsed.map do |item|
          {
            text: item['text'] || item[:text],
            line_number: item['line_number'] || item[:line_number] || 0
          }
        end
      else
        Rails.logger.warn "[SluglineExtractorAgent] Response is not an array: #{parsed.class}"
        return []
      end
    rescue JSON::ParserError => e
      Rails.logger.error "[SluglineExtractorAgent] Failed to parse JSON response: #{e.message}"
      Rails.logger.error "[SluglineExtractorAgent] Response content: #{response[0..500]}..."

      # Fallback: try to extract sluglines using regex
      return extract_sluglines_fallback(response)
    end
  end

  def extract_sluglines_fallback(text)
    Rails.logger.info "[SluglineExtractorAgent] Using fallback regex extraction"

    sluglines = []
    lines = text.split("\n")

    lines.each_with_index do |line, index|
      # Look for typical slugline patterns
      if line.strip.match(/^(INT\.|EXT\.)\s+.+\s+-\s+(DAY|NIGHT|MORNING|EVENING|DAWN|DUSK)/i)
        sluglines << {
          text: line.strip,
          line_number: index + 1
        }
      end
    end

    Rails.logger.info "[SluglineExtractorAgent] Fallback extraction found #{sluglines.length} sluglines"
    return sluglines
  end
end
