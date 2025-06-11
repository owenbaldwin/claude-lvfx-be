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
      - NUMBER. INT. LOCATION - TIME
      - NUMBER. EXT. LOCATION - TIME
      - INT. LOCATION - TIME
      - EXT. LOCATION - TIME
      - Examples: "1. INT. BEDROOM - NIGHT", "15. EXT. BEACH - DAY", "47. INT./EXT. BEDROOM - NIGHT", "EXT. BEDROOM - DAY"
      - Some scripts use "INT./EXT." to indicate a scene that is both inside and outside.
      - Some scripts use numbered scenes, some scripts use roman numerals and some scripts don't have numbered scenes.
      - Some scripts use numbers like "1A" or "1B" to indicate a continuation of the previous scene.

      Please extract ONLY the sluglines and return them as a JSON array of objects with this format:
      [
        {"text": "1. INT. BEDROOM - NIGHT", "line_number": 1},
        {"text": "2. EXT. PARK - DAY", "line_number": 2},
        {"text": "3A. INT. BEDROOM - NIGHT", "line_number": 3},
        {"text": "3B. INT. BEDROOM - DAY", "line_number": 4},
        {"text": "4. EXT. GARDEN - DAY", "line_number": 5},
      ]

      As you can see, when scenes use numbers and letters, then the line_number will become different to the scene number. Line_number is an index.

      Make sure to extract all sluglines until the end of the script, even if they are not in the format above.

      If you find a scene number repeating but followed by "CONT'D" or "(CONT'D)" or "CONTINUED" or "(CONTINUED)" then it is a continuation of the previous scene: just ignore the repeat and continue extracting.

      If no sluglines are found, check the script text for any other headers that might be scene headings. Only stop the slugline extraction when you reach the end of the script.

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
