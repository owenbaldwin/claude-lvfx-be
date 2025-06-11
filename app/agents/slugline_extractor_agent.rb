class SluglineExtractorAgent < ApplicationAgent
  def extract_sluglines(script_text)
    Rails.logger.info "[SluglineExtractorAgent] Starting slugline extraction"

    # Check if script is too large and needs chunking
    if script_text.length > 40000  # Roughly 10k tokens
      Rails.logger.info "[SluglineExtractorAgent] Script is large (#{script_text.length} chars), using chunking approach"
      return extract_sluglines_chunked(script_text)
    end

    prompt = build_slugline_prompt(script_text)

    Rails.logger.info "[SluglineExtractorAgent] Making OpenAI API call with model: #{@model}"
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

  def extract_sluglines_chunked(script_text)
    Rails.logger.info "[SluglineExtractorAgent] Processing script in chunks"

    # Split script into smaller chunks of ~15k characters (roughly 3.5k tokens)
    chunk_size = 15000
    chunks = []

    (0...script_text.length).step(chunk_size) do |i|
      chunk = script_text[i, chunk_size]
      chunks << chunk
    end

    Rails.logger.info "[SluglineExtractorAgent] Split script into #{chunks.length} chunks"

    all_sluglines = []

    chunks.each_with_index do |chunk, index|
      Rails.logger.info "[SluglineExtractorAgent] Processing chunk #{index + 1}/#{chunks.length}"

      prompt = build_slugline_prompt(chunk)
      response = call_openai(prompt)

      if response && !response.empty?
        # Extract content from OpenStruct response
        response_content = response.respond_to?(:content) ? response.content : response.to_s

        if response_content && !response_content.empty?
          chunk_sluglines = parse_sluglines_response(response_content)
          all_sluglines.concat(chunk_sluglines)
          Rails.logger.info "[SluglineExtractorAgent] Chunk #{index + 1} found #{chunk_sluglines.length} sluglines"
        else
          Rails.logger.warn "[SluglineExtractorAgent] Chunk #{index + 1} returned empty content"
        end
      else
        Rails.logger.warn "[SluglineExtractorAgent] Chunk #{index + 1} returned empty response"
      end

      # Small delay between API calls to respect rate limits
      sleep(0.5) if index < chunks.length - 1
    end

    # Remove duplicates (sluglines that might appear across chunk boundaries)
    unique_sluglines = all_sluglines.uniq { |s| s[:text]&.strip&.upcase }

    Rails.logger.info "[SluglineExtractorAgent] Total unique sluglines found: #{unique_sluglines.length}"
    return unique_sluglines
  end

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
