class SceneVerifierAgent < ApplicationAgent
  MAX_SCENES_PER_BATCH = 5  # Process scenes in batches to avoid token limits

  def verify_extracted_scenes(script_text, extracted_scenes)
    log_info "Starting scene verification for #{extracted_scenes.length} scenes"

    # If we have too many scenes, process in batches
    if extracted_scenes.length > MAX_SCENES_PER_BATCH
      return verify_scenes_in_batches(script_text, extracted_scenes)
    end

    # For smaller sets, verify all at once
    verify_scene_batch(script_text, extracted_scenes)
  end

  private

  def verify_scenes_in_batches(script_text, extracted_scenes)
    log_info "Processing #{extracted_scenes.length} scenes in batches of #{MAX_SCENES_PER_BATCH}"

    all_errors = []
    all_missing_scenes = []
    successful_verifications = 0

    # Process scenes in batches
    extracted_scenes.each_slice(MAX_SCENES_PER_BATCH).with_index do |scene_batch, batch_index|
      log_info "Verifying batch #{batch_index + 1} (#{scene_batch.length} scenes)"

      batch_result = verify_scene_batch(script_text, scene_batch)

      if batch_result["success"]
        successful_verifications += scene_batch.length
        log_info "✅ Batch #{batch_index + 1} verification passed"
      else
        all_errors.concat(batch_result["errors"] || [])
        all_missing_scenes.concat(batch_result["missing_scenes"] || [])
        log_error "❌ Batch #{batch_index + 1} verification failed: #{batch_result['errors']&.join(', ')}"
      end

      # Small delay between batches to respect rate limits
      sleep(1) if batch_index < (extracted_scenes.length.to_f / MAX_SCENES_PER_BATCH).ceil - 1
    end

    # Overall result
    overall_success = all_errors.empty?

    log_info "Batch verification complete: #{successful_verifications}/#{extracted_scenes.length} scenes verified successfully"

    {
      "success" => overall_success,
      "errors" => all_errors,
      "missing_scenes" => all_missing_scenes,
      "verified_count" => successful_verifications,
      "total_count" => extracted_scenes.length
    }
  end

  def verify_scene_batch(script_text, scene_batch)
    # Build a condensed version of the script for verification
    condensed_script = build_condensed_script(script_text, scene_batch)

    prompt = build_verification_prompt(condensed_script, scene_batch)

    # Check prompt size before sending
    if prompt.length > 80000  # Roughly 20k tokens
      log_error "Verification prompt too large (#{prompt.length} chars), falling back to basic validation"
      return perform_basic_validation(scene_batch)
    end

    log_info "Making OpenAI API call with model: gpt-4"
    log_info "Prompt length: #{prompt.length} characters"

    response = call_openai(prompt, max_tokens: 2000)

    if response&.content.present?
      log_info "Received response: #{response.content.length} characters"
      return parse_verification_response(response.content)
    else
      log_error "OpenAI returned empty response for verification"
      return {
        "success" => false,
        "errors" => ["No verification response received"],
        "missing_scenes" => []
      }
    end
  end

  def build_condensed_script(script_text, scenes_to_verify)
    # Extract only the portions of the script that contain the scenes we're verifying
    scene_sluglines = scenes_to_verify.map do |scene|
      # Use the original slugline for matching if available, otherwise reconstruct it
      scene["original_slugline"] || begin
        int_ext = scene["int_ext"]&.upcase || "INT"
        location = scene["location"] || "UNKNOWN"
        time = scene["time"] || "DAY"
        "#{int_ext}. #{location} - #{time}"
      end
    end

    lines = script_text.split("\n")
    condensed_lines = []

    scene_sluglines.each do |target_slugline|
      # Find this scene in the script
      lines.each_with_index do |line, index|
        if sluglines_match?(line.strip, target_slugline)
          # Include this scene header and next 10-15 lines
          scene_excerpt = lines[index, 15].join("\n")
          condensed_lines << scene_excerpt
          condensed_lines << "\n--- SCENE BREAK ---\n"
          break
        end
      end
    end

    condensed_script = condensed_lines.join("\n")
    log_info "Built condensed script: #{condensed_script.length} characters from #{scene_sluglines.length} scenes"

    condensed_script
  end

  def sluglines_match?(line1, target_slugline)
    # Normalize both for comparison
    norm1 = normalize_slugline(line1)
    norm2 = normalize_slugline(target_slugline)
    norm1 == norm2
  end

  def normalize_slugline(slugline)
    slugline.to_s.strip.upcase.gsub(/\s+/, ' ').gsub(/^\d+\s+/, '').gsub(/\s+\d+$/, '')
  end

  def build_verification_prompt(condensed_script, extracted_scenes)
    scenes_summary = extracted_scenes.map.with_index do |scene, index|
      "#{index + 1}. #{scene['int_ext']}. #{scene['location']} - #{scene['time']}"
    end.join("\n")

    <<~PROMPT
      You are a script verification expert. Your task is to verify that the extracted scene data accurately represents the scenes in the provided script excerpt.

      EXTRACTED SCENES TO VERIFY:
      #{scenes_summary}

      SCRIPT EXCERPT:
      #{condensed_script}

      Please verify:
      1. Are all the extracted scene headers present in the script?
      2. Do the INT/EXT, LOCATION, and TIME values match what's in the script?
      3. Are there any obvious scenes missing from the extraction?

      Respond with valid JSON in this format:
      {
        "success": true/false,
        "errors": ["list of specific errors found"],
        "missing_scenes": ["list of scene headers that should have been extracted but weren't"],
        "notes": "any additional observations"
      }

      If verification passes, return {"success": true, "errors": [], "missing_scenes": [], "notes": "All scenes verified successfully"}.
    PROMPT
  end

  def perform_basic_validation(scene_batch)
    log_info "Performing basic validation for #{scene_batch.length} scenes"

    errors = []

    scene_batch.each_with_index do |scene, index|
      # Basic field validation
      required_fields = %w[scene_number int_ext location time]
      missing_fields = required_fields.select { |field| scene[field].blank? }

      if missing_fields.any?
        errors << "Scene #{index + 1} missing required fields: #{missing_fields.join(', ')}"
      end

      # Validate int_ext values
      unless %w[INT EXT].include?(scene["int_ext"]&.upcase)
        errors << "Scene #{index + 1} has invalid int_ext: #{scene['int_ext']}"
      end
    end

    {
      "success" => errors.empty?,
      "errors" => errors,
      "missing_scenes" => [],
      "notes" => "Basic validation performed due to size constraints"
    }
  end

  def parse_verification_response(response_content)
    begin
      parsed = JSON.parse(response_content)

      # Ensure all required fields are present
      {
        "success" => parsed["success"] || false,
        "errors" => parsed["errors"] || [],
        "missing_scenes" => parsed["missing_scenes"] || [],
        "notes" => parsed["notes"] || ""
      }

    rescue JSON::ParserError => e
      log_error "Failed to parse verification response: #{e.message}"
      log_error "Response content: #{response_content[0..500]}..."

      # Try to extract success/failure from text response
      if response_content.downcase.include?("success") && !response_content.downcase.include?("fail")
        {
          "success" => true,
          "errors" => [],
          "missing_scenes" => [],
          "notes" => "Verification passed (parsed from text response)"
        }
      else
        {
          "success" => false,
          "errors" => ["Failed to parse verification response"],
          "missing_scenes" => []
        }
      end
    end
  end
end
