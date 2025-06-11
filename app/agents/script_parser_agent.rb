class ScriptParserAgent < ApplicationAgent
  MAX_RETRIES = 3

  def parse_script(script_id)
    script = Script.find(script_id)
    log_info "🎬 Starting script parsing for Script##{script_id} - #{script.title}"

    # Get the script text
    script_text = extract_text_from_script(script)
    return false if script_text.blank?

    # Step 1: Extract sluglines
    sluglines = extract_sluglines(script_text)
    return false if sluglines.empty?

    # Step 2: Extract scene data for each slugline
    extracted_scenes = extract_all_scenes(script_text, sluglines)
    return false if extracted_scenes.empty?

    # Step 3: Verify the extracted scenes
    verification_result = verify_scenes(script_text, extracted_scenes)
    return false unless verification_result["success"]

    # Step 4: Save to database using existing ScriptJsonImporter
    success = save_scenes_to_database(script, extracted_scenes)

    if success
      log_info "🎉 Successfully parsed and saved script #{script_id}"
    else
      log_error "❌ Failed to save scenes to database for script #{script_id}"
    end

    success

  rescue => e
    log_error "💥 Fatal error parsing script #{script_id}: #{e.message}"
    log_error e.backtrace.join("\n")
    false
  end

  private

  def extract_text_from_script(script)
    log_info "📄 Extracting text from script"

    # First, check if script already has scenes_data_json that we can work with
    if script.scenes_data_json.present? && script.scenes_data_json.is_a?(Hash) && script.scenes_data_json["scenes"].present?
      log_info "Found existing scenes_data_json, reconstructing script text"
      return reconstruct_text_from_scenes(script.scenes_data_json)
    end

    # Try to extract from raw_text field (if it exists)
    if script.respond_to?(:raw_text) && script.raw_text.present?
      log_info "Using raw_text field"
      return script.raw_text
    end

    # Try to extract from attached PDF file
    if script.file.attached?
      log_info "Extracting text from attached PDF file"
      text = extract_pdf_text(script.file)
      return text if text.present?
    end

    log_error "No script text available - no raw_text field, attached file failed, or existing scenes data"
    nil
  end

  def reconstruct_text_from_scenes(scenes_data_json)
    log_info "Reconstructing script text from existing scenes data"

    scenes = scenes_data_json["scenes"] || []
    return nil if scenes.empty?

    script_text = ""

    scenes.each do |scene|
      # Add scene header
      int_ext = scene["int_ext"]&.upcase || "INT"
      location = scene["location"] || "UNKNOWN LOCATION"
      time = scene["time"] || "DAY"

      script_text += "\n#{int_ext}. #{location} - #{time}\n\n"

      # Add scene description if present
      if scene["description"].present?
        script_text += "#{scene['description']}\n\n"
      end

      # Add action beats
      action_beats = scene["action_beats"] || []
      action_beats.each do |beat|
        case beat["type"]
        when "dialogue"
          # Add character name and dialogue
          characters = beat["characters"] || []
          if characters.any?
            script_text += "#{characters.first.upcase}\n"
            script_text += "#{beat['content']}\n\n"
          end
        when "action"
          script_text += "#{beat['content']}\n\n"
        end
      end
    end

    log_info "Reconstructed #{script_text.length} characters of text from #{scenes.length} scenes"
    script_text
  end

  def extract_pdf_text(file_attachment)
    tempfile = nil
    begin
      # Download to a properly named temporary file
      tempfile = Tempfile.new(['script', '.pdf'])
      tempfile.binmode

      # Use Rails' built-in download method
      file_attachment.blob.download do |chunk|
        tempfile.write(chunk)
      end
      tempfile.rewind

      # Extract text using pdf-reader
      reader = PDF::Reader.new(tempfile.path)
      text = reader.pages.map(&:text).join("\n")

      log_info "Successfully extracted #{text.length} characters from PDF"
      text

    rescue => e
      log_error "PDF extraction failed: #{e.message}"
      log_error "Error class: #{e.class}"
      nil
    ensure
      tempfile&.close
      tempfile&.unlink
    end
  end

  def extract_sluglines(script_text)
    log_info "🎯 Step 1: Extracting sluglines"

    slugline_agent = SluglineExtractorAgent.new
    sluglines = slugline_agent.extract_sluglines(script_text)

    if sluglines.empty?
      log_error "No sluglines found in script"
      return []
    end

    log_info "Found #{sluglines.length} sluglines"
    sluglines
  end

  def extract_all_scenes(script_text, sluglines)
    log_info "🎭 Step 2: Extracting scene data for #{sluglines.length} scenes"

    scene_agent = SceneExtractorAgent.new
    extracted_scenes = []
    failed_scenes = []

    sluglines.each_with_index do |slugline, index|
      scene_number = index + 1
      log_info "Extracting scene #{scene_number}/#{sluglines.length}: #{slugline}"

      scene_data = scene_agent.extract_scene_data_for_slugline(script_text, slugline, scene_number)

      if scene_data
        extracted_scenes << scene_data
        log_info "✅ Successfully extracted scene #{scene_number}"
      else
        failed_scenes << { slugline: slugline, scene_number: scene_number }
        log_error "❌ Failed to extract scene #{scene_number}"
      end
    end

    log_info "Scene extraction complete: #{extracted_scenes.length} successful, #{failed_scenes.length} failed"

    if failed_scenes.any?
      log_error "Failed scenes: #{failed_scenes.map { |fs| "#{fs[:scene_number]} (#{fs[:slugline]})" }.join(', ')}"
    end

    extracted_scenes
  end

  def verify_scenes(script_text, extracted_scenes)
    log_info "🔍 Step 3: Verifying extracted scenes"

    verifier_agent = SceneVerifierAgent.new
    verification_result = verifier_agent.verify_extracted_scenes(script_text, extracted_scenes)

    if verification_result["success"]
      log_info "✅ Scene verification passed"
    else
      log_error "❌ Scene verification failed"
      log_error "Errors: #{verification_result['errors'].join(', ')}"

      if verification_result["missing_scenes"]&.any?
        log_error "Missing scenes: #{verification_result['missing_scenes'].join(', ')}"
      end
    end

    verification_result
  end

  def save_scenes_to_database(script, extracted_scenes)
    log_info "💾 Step 4: Saving scenes to database"

    begin
      # Format the data for ScriptJsonImporter
      scenes_data = {
        "scenes" => extracted_scenes
      }

      # Update the script with the JSON data
      script.update!(scenes_data_json: scenes_data)

      # Use the existing ScriptJsonImporter to save to database
      importer = ScriptJsonImporter.new(script: script)
      importer.import!

      log_info "✅ Successfully saved #{extracted_scenes.length} scenes to database"
      true

    rescue => e
      log_error "Failed to save scenes to database: #{e.message}"
      log_error e.backtrace.join("\n")
      false
    end
  end
end
