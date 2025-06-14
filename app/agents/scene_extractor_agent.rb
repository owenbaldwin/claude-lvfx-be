class SceneExtractorAgent < ApplicationAgent
  def extract_scene_data_for_slugline(script_text, slugline, scene_number)
    Rails.logger.info "[SceneExtractorAgent] Extracting scene data for: #{slugline}"

    # Extract just the relevant scene content instead of the entire script
    scene_content = extract_scene_content(script_text, slugline)

    if scene_content.blank?
      Rails.logger.error "[SceneExtractorAgent] Could not find scene content for: #{slugline}"
      return nil
    end

    Rails.logger.info "[SceneExtractorAgent] Extracted scene content: #{scene_content.length} characters"

    prompt = build_scene_extraction_prompt(scene_content, slugline, scene_number)

    Rails.logger.info "[SceneExtractorAgent] Making OpenAI API call with GPT-4.1 nano"
    Rails.logger.info "[SceneExtractorAgent] Prompt length: #{prompt.length} characters"

    response = call_openai(prompt)

    if response && !response.empty?
      # Extract content from OpenStruct response
      response_content = response.respond_to?(:content) ? response.content : response.to_s

      if response_content && !response_content.empty?
        begin
          parsed_response = JSON.parse(response_content)

          if parsed_response.is_a?(Hash) && parsed_response["scene_number"]
            Rails.logger.info "[SceneExtractorAgent] ✅ Successfully extracted scene #{scene_number}"
            # Add the original slugline text to the response
            parsed_response["original_slugline"] = slugline.is_a?(Hash) ? slugline[:text] : slugline.to_s
            return parsed_response
          else
            Rails.logger.error "[SceneExtractorAgent] Invalid response format for scene #{scene_number}"
            return nil
          end
        rescue JSON::ParserError => e
          Rails.logger.error "[SceneExtractorAgent] Failed to parse JSON response for scene #{scene_number}: #{e.message}"
          Rails.logger.error "[SceneExtractorAgent] Response content: #{response_content[0..500]}..."
          return nil
        end
      else
        Rails.logger.error "[SceneExtractorAgent] OpenAI returned empty content for scene #{scene_number}"
        return nil
      end
    else
      Rails.logger.error "[SceneExtractorAgent] OpenAI returned empty response for scene #{scene_number}"
      return nil
    end
  end

  private

  def extract_scene_content(script_text, target_slugline)
    slugline_text = target_slugline.is_a?(Hash) ? target_slugline[:text] : target_slugline.to_s
    log_info "Attempting to extract content for slugline: '#{slugline_text}'"

    lines = script_text.split("\n")
    scene_start_index = nil
    scene_end_index = lines.length - 1

    # Find the start of the target scene
    lines.each_with_index do |line, index|
      # Check if this line matches our target slugline (with some flexibility for formatting)
      if sluglines_match?(line.strip, slugline_text)
        scene_start_index = index
        log_info "Found scene start at line #{index + 1}: #{line.strip}"
        break
      end
    end

    if scene_start_index.nil?
      log_error "FAILED to find start of scene for: '#{slugline_text}'"
      return nil
    end

    # Find the end of the scene (next slugline)
    ((scene_start_index + 1)...lines.length).each do |index|
      line = lines[index].strip
      if looks_like_slugline?(line)
        scene_end_index = index - 1
        Rails.logger.info "[SceneExtractorAgent] Found scene end at line #{index}: #{line}"
        break
      end
    end

    # Extract the scene content
    scene_lines = lines[scene_start_index..scene_end_index]
    scene_content = scene_lines.join("\n").strip

    Rails.logger.info "[SceneExtractorAgent] Extracted scene: #{scene_lines.length} lines, #{scene_content.length} characters"

    return scene_content
  end

  def sluglines_match?(line1, target_slugline)
    # Normalize both sluglines for comparison
    normalized_line1 = normalize_slugline_for_matching(line1)
    normalized_target = normalize_slugline_for_matching(target_slugline.is_a?(Hash) ? target_slugline[:text] || target_slugline["text"] : target_slugline.to_s)

    Rails.logger.debug "[SceneExtractorAgent] Comparing: '#{normalized_line1}' vs '#{normalized_target}'"

    # First try exact match
    return true if normalized_line1 == normalized_target

    # Try fuzzy matching - check if they contain the same key components
    line1_components = extract_key_components(line1)
    target_components = extract_key_components(target_slugline.is_a?(Hash) ? target_slugline[:text] || target_slugline["text"] : target_slugline.to_s)

    # Match if they have the same INT/EXT, location, and time components
    return line1_components[:int_ext] == target_components[:int_ext] &&
           line1_components[:location] == target_components[:location] &&
           line1_components[:time] == target_components[:time]
  end

  def extract_key_components(slugline_text)
    text = slugline_text.to_s.strip.upcase

    # Extract INT/EXT
    int_ext = if text.match(/\bINT\b/)
                "INT"
              elsif text.match(/\bEXT\b/)
                "EXT"
              else
                "INT" # default
              end

    # Extract location and time
    location = ""
    time = "DAY" # default

    # Remove scene number and INT/EXT prefix first
    clean_text = text.gsub(/^\d+[A-Z]?\s*\.?\s*/, '').gsub(/^(?:INT|EXT)\.?\s*/, '')

    # Try different patterns to extract location and time
    time_words = %w[DAY NIGHT MORNING EVENING DAWN DUSK AFTERNOON SUNSET SUNRISE]
    time_pattern = time_words.join('|')

    # Pattern 1: Location - Time (with dash/hyphen separator)
    if match = clean_text.match(/^(.+?)\s*[-–]\s*(#{time_pattern})/i)
      location = match[1].strip.gsub(/\s+/, ' ')
      time = match[2].strip
    # Pattern 2: Location Time (space separated, time at end)
    elsif match = clean_text.match(/^(.+?)\s+(#{time_pattern})$/i)
      location = match[1].strip.gsub(/\s+/, ' ')
      time = match[2].strip
    # Pattern 3: Just location, no time specified
    elsif clean_text.present?
      location = clean_text.strip.gsub(/\s+/, ' ')
      # Check if the location ends with a time word
      if match = location.match(/^(.+?)\s+(#{time_pattern})$/i)
        location = match[1].strip
        time = match[2].strip
      end
    end

    {
      int_ext: int_ext,
      location: location,
      time: time
    }
  end

  def normalize_slugline_for_matching(slugline)
    # More robust normalization that preserves key structure
    normalized = slugline.to_s.strip.upcase

    # Remove scene numbers from the start - handle both "1. EXT" and "1     EXT" formats
    # This regex matches: number + optional letter + (period OR multiple spaces) + optional spaces
    normalized = normalized.gsub(/^\d+[A-Z]?(\.\s*|\s{2,})/, '')

    # Remove trailing scene numbers (common in script format like "1     EXT. LOCATION DAY     1")
    normalized = normalized.gsub(/\s+\d+[A-Z]?$/, '')

    # Normalize multiple spaces to single spaces
    normalized = normalized.gsub(/\s+/, ' ')

    # Remove trailing whitespace and periods
    normalized = normalized.strip.gsub(/\.$/, '')

    return normalized
  end

  def looks_like_slugline?(line)
    # Check if a line looks like a slugline
    return false if line.blank?

    # Remove leading scene numbers for pattern matching
    normalized_line = line.strip.gsub(/^\d+\s+/, '')

    # Common slugline patterns
    slugline_patterns = [
      /^(INT\.|EXT\.)\s+.+\s+-\s+(DAY|NIGHT|MORNING|EVENING|DAWN|DUSK)/i,
      /^(INTERIOR|EXTERIOR)\s+.+\s+-\s+(DAY|NIGHT|MORNING|EVENING|DAWN|DUSK)/i,
      /^(INT|EXT)\s+.+\s+(DAY|NIGHT|MORNING|EVENING|DAWN|DUSK)/i,
      # Handle cases without explicit time
      /^(INT\.|EXT\.)\s+.+/i
    ]

    slugline_patterns.any? { |pattern| normalized_line.match?(pattern) }
  end

  # Scene number: #{scene_number}
  def build_scene_extraction_prompt(scene_content, slugline, scene_number)
    <<~PROMPT
      You are an expert script parser specializing in extracting detailed scene information from movie scripts.

      Your task is to analyze the provided scene content and extract all the information for this specific scene.

      Scene to extract: "#{slugline}"


      You need to extract:
      1. Parse the slugline to identify the scene number (if present), INT/EXT, LOCATION, and TIME
      2. Extract all characters that appear in this scene
      3. Extract all dialogue and action beats in chronological order
      4. Extract the scene description if present

      Scene content to analyze:
      #{scene_content}

      Return your response as valid JSON in this EXACT format:
      {
        "scene_number": "scene number (as parsed from slugline)",
        "int_ext": "INT" or "EXT" (parsed from slugline),
        "location": "LOCATION NAME" (parsed from slugline),
        "time": "TIME OF DAY" (parsed from slugline),
        "description": "write a short description of the scene in your own words",
        "characters": ["CHARACTER1", "CHARACTER2", ...],
        "action_beats": [
          {
            "type": "action",
            "content": "Action description text",
            "characters": ["CHARACTER1", "CHARACTER2", ...] or [] if no specific characters
          },
          {
            "type": "dialogue",
            "content": "The actual dialogue text",
            "characters": ["SPEAKING_CHARACTER"]
          }, ...
        ]
      }

      Important parsing rules:
      - Scene number: Extract the scene number from the slugline if present. It will be a number or a roman numeral or a number and a letter. If it contains a letter, then include the letter in the scene number.
      - If you encounter a scene number that repeats but is followed by "CONT'D" or "(CONT'D)" or "CONTINUED" or "(CONTINUED)" then it is a continuation of the previous scene: just ignore the repeat and continue extracting until you reach the next scene (different scene number and/or different INT/EXT and/or different location and/or different time).
      - INT/EXT: Extract "INT" or "EXT" from the slugline
      - LOCATION: Extract the location name (e.g., "LIVING ROOM", "BEACH")
      - TIME: Extract time of day (e.g., "DAY", "NIGHT", "SUNSET")
      - Characters: Include ALL characters that appear in the scene (speaking or mentioned)
      - Action beats: Separate action descriptions and dialogue into individual beats
      - Dialogue: Each piece of dialogue should be a separate beat with the speaking character
      - Content: Include the actual text content, not just summaries

      Make sure to extract all the information from the scene exactly as it is in the script. Be as accurate as possible.

      Ensure the JSON is valid and properly formatted.
    PROMPT
  end
end
