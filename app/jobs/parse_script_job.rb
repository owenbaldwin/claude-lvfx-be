# app/jobs/parse_script_job.rb
require 'pdf/reader'
require 'json'
require 'thread'        # for Mutex
require "ruby/openai"

class ParseScriptJob < ApplicationJob
  queue_as :default

  def perform(production_id, script_id, script_parse_id = nil)
    # Handle both old and new calling conventions for backward compatibility
    script_parse = script_parse_id ? ScriptParse.find(script_parse_id) : nil

    begin
      script = Script.find(script_id)

      # Update status to processing if we have a tracking record
      script_parse&.update!(status: 'processing')

      # Check if script already has parsed data and clear it if reprocessing
      if script.scenes_data_json.present?
        Rails.logger.info "[ParseScriptJob] 🔄 Clearing existing parsed data for Script##{script_id}"
        script.update!(scenes_data_json: nil)

        # Also clean up any existing database records from previous imports
        script.scenes.destroy_all
        script.action_beats.destroy_all
      end

      pdf_data = script.file.download

      # 1) Read entire PDF → raw_text
      reader   = PDF::Reader.new(StringIO.new(pdf_data))
      raw_text = reader.pages.map(&:text).join("\n\n")

      # 2) First GPT call: extract sluglines JSON as before...
      sluglines_prompt = <<~PROMPT
        You are a script‐analysis assistant. Extract ONLY the scene headings (sluglines) from this film script.

        **CRITICAL REQUIREMENTS:**
        1. Return VALID JSON only - no markdown, no extra text, no explanations
        2. Use this EXACT format:
        {
          "scenes": [
            { "index": 1, "text": "1 INT. HOUSE – DAY" },
            { "index": 2, "text": "2 EXT. GARDEN – DAY" }
          ]
        }

        **EXTRACTION RULES:**
        • "index": Sequential counter starting at 1 (regardless of scene's printed number)
        • "text": EXACT scene heading as written, including any suffix like "3A", "10B"
        • Extract lines starting with: scene number OR "INT." OR "EXT." OR "INT./EXT."
        • Pattern: [NUMBER][SPACE][INT./EXT.][SPACE][LOCATION][SPACE]–[SPACE][TIME]
        • Preserve original spacing, casing, and punctuation EXACTLY
        • Skip "CONT'D" or "CONTINUED" variations of same slugline
        • Do NOT modify, renumber, or invent sluglines
        • Process the ENTIRE script to the end

        **EXAMPLES:**
        ✓ "3A EXT. ALLEYWAY – DAY"
        ✓ "10B INT./EXT. CAR – NIGHT"
        ✓ "INT. KITCHEN – MORNING" (if no number)
        ✗ Skip: "3A EXT. ALLEYWAY – DAY (CONT'D)"

        Script text:
        #{raw_text}
      PROMPT

      client = OpenAI::Client.new(
        access_token: ENV.fetch("OPENAI_API_KEY"),
        request_timeout: 300
      )

      slug_response = client.chat(
        parameters: {
          model:       "gpt-4o",  # Use more reliable model
          messages:    [{ role: "user", content: sluglines_prompt }],
          max_tokens:  16_384,
          temperature: 0
        }
      )

      Rails.logger.info "🤖 GPT‐4 raw slugline response for Script##{script_id}: #{slug_response.to_json}"

      # Extract and validate JSON response
      sluglines_json = slug_response.dig("choices", 0, "message", "content")
      unless sluglines_json.is_a?(String) && sluglines_json.strip.length > 0
        Rails.logger.error "[ParseScriptJob] ✗ Empty sluglines response for Script##{script_id}"
        raise "Empty response from OpenAI for sluglines extraction"
      end

      # Clean and validate JSON
      cleaned_json = clean_json_response(sluglines_json)
      parsed = JSON.parse(cleaned_json)

      unless parsed.is_a?(Hash) && parsed["scenes"].is_a?(Array)
        Rails.logger.error "[ParseScriptJob] ✗ Invalid JSON structure: #{parsed.inspect}"
        raise "Invalid JSON structure in sluglines response"
      end

      all_scenes = parsed.fetch("scenes")

      if all_scenes.empty?
        Rails.logger.error "[ParseScriptJob] ✗ No scenes extracted from script"
        raise "No scenes found in script"
      end

      # Validate scene structure
      all_scenes.each_with_index do |scene, idx|
        unless scene.is_a?(Hash) && scene["index"].present? && scene["text"].present?
          Rails.logger.error "[ParseScriptJob] ✗ Invalid scene structure at index #{idx}: #{scene.inspect}"
          raise "Invalid scene structure in response"
        end
      end

      # 3) Build index → slugline text and collect indices
      index_to_slug = {}
      all_indices   = []

      all_scenes.each do |entry|
        idx       = entry.fetch("index").to_i
        text_slug = entry.fetch("text")
        index_to_slug[idx] = text_slug
        all_indices << idx
      end

      all_indices.sort!

      # 4) Build index → "next slugline" (or "END OF SCRIPT")
      index_to_until_slug = {}
      all_indices.each_with_index do |idx, i|
        if i < all_indices.size - 1
          next_idx = all_indices[i + 1]
          index_to_until_slug[idx] = index_to_slug[next_idx]
        else
          index_to_until_slug[idx] = "END OF SCRIPT"
        end
      end

      # 5) PRECOMPUTE CHARACTER‐OFFSETS OF EACH SLUGLINE IN raw_text
      slug_offset_map = {}
      raw_lines       = raw_text.lines

      all_indices.each do |idx|
        slug            = index_to_slug[idx]
        normalized_slug = normalize_for_matching(slug)
        found_pos = find_slugline_position(raw_text, raw_lines, slug, normalized_slug)

        if found_pos.nil?
          Rails.logger.error "[ParseScriptJob] ✗ Could not locate slugline '#{slug}' in raw_text"
          slug_offset_map[idx] = 0
        else
          slug_offset_map[idx] = found_pos
        end
      end

      # 6) Process scenes sequentially to avoid race conditions
      scene_results = {}

      all_indices.each do |scene_index|
        Rails.logger.info "[ParseScriptJob] 🎬 Processing scene #{scene_index}/#{all_indices.size}"

        start_slug = index_to_slug.fetch(scene_index)
        until_slug = index_to_until_slug.fetch(scene_index)

        # Extract scene content
        start_pos = slug_offset_map[scene_index]
        end_pos = if until_slug == "END OF SCRIPT"
                    raw_text.length
                  else
                    next_slug = until_slug.strip.gsub(/\s+/, " ")
                    found_end_pos = nil
                    raw_lines.each do |line|
                      if line.strip.gsub(/\s+/, " ") == next_slug
                        found_end_pos = raw_text.index(line)
                        break
                      end
                    end
                    found_end_pos || raw_text.length
                  end

        scene_chunk = raw_text[start_pos...end_pos]
        if scene_chunk.blank?
          Rails.logger.error "[ParseScriptJob] ✗ scene_chunk blank for scene #{scene_index}"
          scene_results[scene_index] = { "index" => scene_index, "error" => "empty_scene_content" }
          next
        end

        # Process scene with retries
        parsed_scene = process_scene_with_retries(
          client, scene_chunk, start_slug, until_slug, scene_index
        )

        if parsed_scene
          scene_results[scene_index] = parsed_scene
          Rails.logger.info "[ParseScriptJob] ✅ Scene #{scene_index} parsed successfully"
        else
          scene_results[scene_index] = { "index" => scene_index, "error" => "parsing_failed" }
          Rails.logger.error "[ParseScriptJob] ✗ Failed to parse scene #{scene_index}"
        end
      end

      # 7) Build final sorted array
      final_array = all_indices.map do |idx|
        scene_results.fetch(idx, { "index" => idx, "error" => "missing_result" })
      end

      final_payload = { "scenes" => final_array }
      Rails.logger.info "[ParseScriptJob] 🏁 Final combined scenes JSON for Script##{script_id} with #{final_array.size} scenes"

      # === SAVE JSON AND IMPORT ===
      script.update!(scenes_data_json: final_payload)
      Rails.logger.info "[ParseScriptJob] ✔️ JSON stored to script.scenes_data_json"

      # === INSTANTLY HAND OFF TO ScriptJsonImporter ===
      begin
        ScriptJsonImporter.new(script: script).import!
        Rails.logger.info "[ParseScriptJob] ✔️ ScriptJsonImporter succeeded for Script##{script_id}"

        # Update script_parse with successful results if we have a tracking record
        if script_parse
          script_parse.update!(
            status: 'completed',
            results_json: {
              script_id: script_id,
              scenes_count: final_payload["scenes"]&.count || 0,
              scenes_data: final_payload,
              completed_at: Time.current
            }
          )
        end

      rescue => e
        Rails.logger.error "[ParseScriptJob] ✗ ScriptJsonImporter failed for Script##{script_id}: #{e.class}: #{e.message}"

        # Update script_parse with error if we have a tracking record
        if script_parse
          script_parse.update!(
            status: 'failed',
            error: "ScriptJsonImporter failed: #{e.class}: #{e.message}"
          )
        end
        raise
      end

    rescue => e
      Rails.logger.error "[ParseScriptJob] ✗ #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Update script_parse with error if we have a tracking record
      if script_parse
        script_parse.update!(
          status: 'failed',
          error: "#{e.class}: #{e.message}"
        )
      end

      raise
    end
  end

  private

  def clean_json_response(raw_response)
    # Remove markdown formatting and extra text
    cleaned = raw_response.strip

    # Extract JSON content between first { and last }
    start_idx = cleaned.index('{')
    end_idx = cleaned.rindex('}')

    if start_idx && end_idx && start_idx < end_idx
      cleaned = cleaned[start_idx..end_idx]
    end

    # Clean up common formatting issues
    cleaned.gsub(/```json\s*/, '')
           .gsub(/```\s*$/, '')
           .gsub(/^\s*```/, '')
           .strip
  end

  def normalize_for_matching(str)
    str
      .gsub(/['']/, "'")                      # map curly apostrophes → straight
      .gsub(/[–—‒]/, "-")                     # normalize any dash → hyphen
      .gsub(/\b(INT)\.{1,}/, '\1')            # collapse any run of "." after INT
      .gsub(/\b(EXT)\.{1,}/, '\1')            # collapse any run of "." after EXT
      .gsub(/[^A-Za-z0-9\-' ]/, " ")          # keep only letters, digits, hyphen, apostrophe, space
      .strip
      .gsub(/\s+/, " ")
  end

  def find_slugline_position(raw_text, raw_lines, slug, normalized_slug)
    # 1) Try exact‐line matching after normalization
    raw_lines.each do |line|
      if normalize_for_matching(line) == normalized_slug
        return raw_text.index(line)
      end
    end

    # 2) Try "sceneNumber + first word of location" match
    parts = slug.strip.split(/\s+/, 3)
    if parts.size == 3
      scene_num, int_ext, location_rest = parts
      norm_num  = normalize_for_matching(scene_num)
      norm_loc1 = normalize_for_matching(location_rest).split(" ").first
      raw_lines.each do |line|
        nl = normalize_for_matching(line)
        if nl.include?(norm_num) && nl.include?(norm_loc1)
          return raw_text.index(line)
        end
      end
    end

    # 3) Fall back to regex search
    re_str = normalized_slug
            .gsub(/[-]/, "\\-")    # escape hyphens for the regex
            .gsub(/\s+/, "\\s+")   # run of spaces in slug → \s+
    regex = /#{re_str}/i
    match_data = raw_text.match(regex)
    match_data&.begin(0)
  end

  def process_scene_with_retries(client, scene_chunk, start_slug, until_slug, scene_index)
    retries_left = 3

    while retries_left > 0
      begin
        prompt = build_scene_detail_prompt(scene_chunk, start_slug, until_slug, scene_index)

        response = client.chat(
          parameters: {
            model:       "gpt-4o",  # Use more reliable model
            messages:    [{ role: "user", content: prompt }],
            max_tokens:  16_384,
            temperature: 0
          }
        )

        raw_content = response.dig("choices", 0, "message", "content")

        if raw_content.blank?
          Rails.logger.error "[ParseScriptJob] ✗ Scene #{scene_index} returned empty content"
          retries_left -= 1
          next
        end

        # Log the raw response for debugging
        Rails.logger.debug "[ParseScriptJob] 🔍 Scene #{scene_index} raw GPT response: #{raw_content}"

        # Clean and parse JSON
        cleaned_content = clean_json_response(raw_content)
        parsed_scene = JSON.parse(cleaned_content)

        # Log parsed structure for debugging
        Rails.logger.debug "[ParseScriptJob] 🔍 Scene #{scene_index} parsed fields: #{parsed_scene.keys.inspect}"

        # Validate required fields
        if validate_scene_structure(parsed_scene, scene_index)
          return parsed_scene
        else
          retries_left -= 1
          Rails.logger.warn "[ParseScriptJob] ⚠️ Scene #{scene_index} validation failed, retrying (#{retries_left} left)"
          Rails.logger.warn "[ParseScriptJob] 🔍 Failed validation for: #{parsed_scene.inspect}"
        end

      rescue JSON::ParserError => parse_err
        Rails.logger.error "[ParseScriptJob] ✗ JSON parse failed for scene #{scene_index}: #{parse_err.message}"
        retries_left -= 1

        if retries_left > 0
          Rails.logger.info "[ParseScriptJob] 🔄 Retrying scene #{scene_index} (#{retries_left} left)"
          sleep(1)
        end

      rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Net::ReadTimeout => e
        retries_left -= 1
        Rails.logger.warn "[ParseScriptJob] ⚠️ Network error for scene #{scene_index}, retrying (#{retries_left} left): #{e.class}"
        sleep(2 + rand(3)) if retries_left > 0

      rescue => e
        Rails.logger.error "[ParseScriptJob] ✗ Unexpected error for scene #{scene_index}: #{e.class}: #{e.message}"
        retries_left -= 1
      end
    end

    nil # All retries exhausted
  end

  def validate_scene_structure(parsed_scene, scene_index)
    return false unless parsed_scene.is_a?(Hash)

    required_fields = %w[scene_index scene_number int_ext location time]
    required_fields.each do |field|
      unless parsed_scene[field].present?
        Rails.logger.error "[ParseScriptJob] ✗ Scene #{scene_index} missing required field: #{field}"
        return false
      end
    end

    # Validate action_beats is an array
    unless parsed_scene["action_beats"].is_a?(Array)
      Rails.logger.error "[ParseScriptJob] ✗ Scene #{scene_index} action_beats is not an array"
      return false
    end

    # Validate characters is an array
    unless parsed_scene["characters"].is_a?(Array)
      Rails.logger.error "[ParseScriptJob] ✗ Scene #{scene_index} characters is not an array"
      return false
    end

    true
  end

  def build_scene_detail_prompt(scene_chunk, start_slug, until_slug, index)
    <<~PROMPT
      You are a script analysis assistant. Extract scene details from this single scene.

      **CRITICAL: Return VALID JSON only. No markdown, no extra text, no explanations.**

      **EXACT FORMAT REQUIRED:**
      {
        "scene_index": #{index},
        "scene_number": <extract number from slugline or use #{index}>,
        "int_ext": "<INT. or EXT. or INT./EXT.>",
        "location": "<location name>",
        "time": "<time of day>",
        "extra": "<CONT'D or other info if present>",
        "description": "<brief scene description>",
        "characters": ["CHARACTER1", "CHARACTER2"],
        "action_beats": [
          {
            "type": "action",
            "characters": ["CHARACTER1"],
            "indications": "",
            "content": "Action description"
          },
          {
            "type": "dialogue",
            "characters": ["CHARACTER2"],
            "indications": "(O.S.)",
            "content": "Line of dialogue"
          }
        ]
      }

      **CRITICAL REQUIREMENTS:**
      • ALL fields are MANDATORY - never omit any field
      • If time is unclear, use "DAY" as default
      • If location is unclear, extract best guess from slugline
      • If no characters found, use empty array []
      • If no action beats, use empty array []
      • Always include "extra" field (use "" if empty)
      • Always include "description" field (use brief summary if unclear)

      **FIELD EXTRACTION RULES:**
      • scene_number: Extract number from "#{start_slug}" or use #{index}
      • int_ext: Extract "INT." or "EXT." or "INT./EXT." from slugline
      • location: Extract location name from slugline
      • time: Extract time from slugline (DAY, NIGHT, MORNING, etc.) - DEFAULT to "DAY" if unclear
      • extra: Extract any additional info like "CONT'D" - use "" if none
      • description: Brief 1-2 sentence summary of what happens in scene
      • characters: All characters who speak or are mentioned by name
      • type: "action" or "dialogue" only
      • Split scene into logical action/dialogue beats
      • Keep original text content without modification

      **SCENE TEXT FROM "#{start_slug}" UNTIL "#{until_slug}":**
      #{scene_chunk}
    PROMPT
  end
end
