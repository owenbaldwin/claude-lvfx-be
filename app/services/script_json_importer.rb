# app/services/script_json_importer.rb
require 'set'

class ScriptJsonImporter
  # Usage:
  #   importer = ScriptJsonImporter.new(script: some_script)
  #   importer.import!
  #
  # This reads `script.scenes_data_json` (a Hash) and populates:
  #   Scene, ActionBeat, Character, CharacterAppearance.
  #
  def initialize(script:)
    @script     = script
    @production = script.production
    @json_data  = script.scenes_data_json || {}   # expecting {"scenes"=>[ ... ]}
    @created_characters = {}  # key: downcased name, value: Character record
    @imported_scene_numbers = Set.new  # Track imported scene numbers to prevent duplicates
    @imported_beat_numbers = {}        # scene_id => Set of beat numbers
  end

  def import!
    unless @script.scenes_data_json.is_a?(Hash) && @script.scenes_data_json["scenes"].is_a?(Array)
      raise "No valid JSON found on script.scenes_data_json"
    end

    scenes_data = @script.scenes_data_json["scenes"]
    if scenes_data.empty?
      Rails.logger.warn "[ScriptJsonImporter] ⚠️ No scenes found in JSON data"
      return
    end

    Rails.logger.info "[ScriptJsonImporter] 📥 Starting import of #{scenes_data.size} scenes for Script##{@script.id}"

    ActiveRecord::Base.transaction do
      # Clear existing data to prevent duplicates
      clear_existing_data

      # Import scenes in order
      import_scenes
    end

    Rails.logger.info "[ScriptJsonImporter] ✅ Import succeeded for Script##{@script.id}"
  rescue => e
    Rails.logger.error "[ScriptJsonImporter] ✗ Import failed for Script##{@script.id}: #{e.class}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end

  private

  def clear_existing_data
    # Remove existing scenes and their dependencies for this script
    existing_scenes = Scene.where(script_id: @script.id)
    existing_action_beats = ActionBeat.where(script_id: @script.id)

    Rails.logger.info "[ScriptJsonImporter] 🧹 Clearing #{existing_scenes.count} existing scenes and #{existing_action_beats.count} action beats"

    # Clear character appearances first to avoid foreign key issues
    CharacterAppearance.where(scene_id: existing_scenes.ids).delete_all
    CharacterAppearance.where(action_beat_id: existing_action_beats.ids).delete_all

    # Clear action beats and scenes
    existing_action_beats.delete_all
    existing_scenes.delete_all
  end

  def import_scenes
    scenes_data = @json_data.fetch("scenes", [])
    successful_imports = 0
    failed_imports = 0

    scenes_data.each_with_index do |scene_hash, index|
      begin
        scene_record = create_scene_from_json(scene_hash, index + 1)

        if scene_record&.persisted?
          import_scene_level_characters(scene_hash.fetch("characters", []), scene_record)
          import_action_beats(scene_hash.fetch("action_beats", []), scene_record)
          successful_imports += 1
          Rails.logger.debug "[ScriptJsonImporter] ✅ Imported scene #{scene_record.number}"
        else
          failed_imports += 1
          Rails.logger.warn "[ScriptJsonImporter] ⚠️ Failed to create scene at index #{index}"
        end
      rescue => e
        failed_imports += 1
        Rails.logger.error "[ScriptJsonImporter] ✗ Error importing scene at index #{index}: #{e.class}: #{e.message}"
      end
    end

    Rails.logger.info "[ScriptJsonImporter] 📊 Import complete: #{successful_imports} successful, #{failed_imports} failed"
  end

  def create_scene_from_json(scene_hash, fallback_number)
    # 1) Skip any "error" entries
    if scene_hash["error"].present?
      Rails.logger.warn "[ScriptJsonImporter] skipping scene index #{scene_hash['scene_index'] || 'unknown'} (#{scene_hash['error']})"
      return nil
    end

    # 2) Extract and validate scene number
    raw_number = scene_hash["scene_number"] || scene_hash["scene_index"] || fallback_number
    scene_number = extract_scene_number(raw_number)

    if scene_number.nil?
      Rails.logger.error "[ScriptJsonImporter] ✗ Could not determine scene number from: #{raw_number.inspect}"
      return nil
    end

    # 3) Check for duplicate scene numbers
    if @imported_scene_numbers.include?(scene_number)
      Rails.logger.warn "[ScriptJsonImporter] ⚠️ Duplicate scene number #{scene_number}, skipping"
      return nil
    end

    # 4) Validate required fields
    required_fields = %w[int_ext location time]
    missing_fields = required_fields.select { |field| scene_hash[field].blank? }

    if missing_fields.any?
      Rails.logger.error "[ScriptJsonImporter] ✗ Scene #{scene_number} missing required fields: #{missing_fields.join(', ')}"
      return nil
    end

    # 5) Extract and clean field values
    raw_int_ext  = scene_hash.fetch("int_ext").to_s.strip
    location     = scene_hash.fetch("location").to_s.strip
    time_of_day  = scene_hash.fetch("time").to_s.strip
    description  = scene_hash["description"].to_s.strip.presence
    extra_info   = scene_hash["extra"].to_s.strip.presence

    # Validate field content
    if location.empty? || time_of_day.empty?
      Rails.logger.error "[ScriptJsonImporter] ✗ Scene #{scene_number} has empty location or time"
      return nil
    end

    # 6) Map int_ext and validate
    int_ext_mapped = map_int_ext(raw_int_ext)
    if int_ext_mapped.nil?
      Rails.logger.error "[ScriptJsonImporter] ✗ Scene #{scene_number} has invalid int_ext: #{raw_int_ext}"
      return nil
    end

    # 7) Build scene attributes
    scene_name = build_scene_name(raw_int_ext, location, time_of_day)
    scene_attrs = {
      production_id: @production.id,
      script_id:     @script.id,
      # sequence_id left nil - will be assigned manually later
      number:        scene_number,
      int_ext:       int_ext_mapped,
      location:      location,
      day_night:     normalize_time_of_day(time_of_day),
      name:          scene_name,
      description:   description,
      is_active:     true
    }

    # 8) Create scene with validation
    scene = Scene.new(scene_attrs)
    if scene.save
      @imported_scene_numbers.add(scene_number)
      @imported_beat_numbers[scene.id] = Set.new
      scene
    else
      Rails.logger.error "[ScriptJsonImporter] ✗ Scene##{scene_number} save failed: #{scene.errors.full_messages.join(', ')}"
      nil
    end
  end

  def extract_scene_number(raw_number)
    return nil if raw_number.blank?

    # Try to convert to integer
    if raw_number.is_a?(Numeric)
      return raw_number.to_i
    end

    # Extract number from string (handle cases like "3A", "10B", etc.)
    number_match = raw_number.to_s.match(/\A(\d+)/)
    number_match ? number_match[1].to_i : nil
  end

  def build_scene_name(int_ext, location, time_of_day)
    "#{int_ext} #{location} – #{time_of_day}".truncate(100)
  end

  def normalize_time_of_day(time_str)
    # Convert to lowercase and handle common variations
    normalized = time_str.downcase.strip

    case normalized
    when /\bday\b/, /\bmorning\b/, /\bafternoon\b/
      "day"
    when /\bnight\b/, /\bevening\b/, /\bdusk\b/, /\bdawn\b/
      "night"
    else
      normalized.presence || "day"  # Default to "day"
    end
  end

  def import_scene_level_characters(character_names, scene_record)
    return unless character_names.is_a?(Array)

    character_names.each do |raw_name|
      name = clean_character_name(raw_name)
      next if name.blank?

      begin
        create_character_and_appearance(name, scene: scene_record, action_beat: nil)
      rescue => e
        Rails.logger.error "[ScriptJsonImporter] ✗ Failed to create character appearance for '#{name}' in scene #{scene_record.number}: #{e.message}"
      end
    end
  end

  def import_action_beats(action_beats_array, scene_record)
    return unless action_beats_array.is_a?(Array)

    beat_numbers = @imported_beat_numbers[scene_record.id]

    action_beats_array.each_with_index do |beat_hash, idx|
      begin
        beat_number = idx + 1

        # Check for duplicate beat numbers within this scene
        if beat_numbers.include?(beat_number)
          Rails.logger.warn "[ScriptJsonImporter] ⚠️ Duplicate action beat #{beat_number} in scene #{scene_record.number}, skipping"
          next
        end

        # Validate beat structure
        unless beat_hash.is_a?(Hash) && beat_hash["type"].present? && beat_hash["content"].present?
          Rails.logger.warn "[ScriptJsonImporter] ⚠️ Invalid action beat structure at index #{idx} in scene #{scene_record.number}"
          next
        end

        beat_type = normalize_beat_type(beat_hash["type"])
        content = beat_hash["content"].to_s.strip
        notes = beat_hash["indications"].to_s.strip.presence
        beat_chars = beat_hash.fetch("characters", [])

        # Skip empty content
        if content.blank?
          Rails.logger.warn "[ScriptJsonImporter] ⚠️ Empty content for action beat #{beat_number} in scene #{scene_record.number}"
          next
        end

        # Create action beat
        ab_attrs = {
          scene_id:      scene_record.id,
          production_id: @production.id,
          script_id:     @script.id,
          # sequence_id left nil - will be assigned manually later
          number:        beat_number,
          beat_type:     beat_type,
          text:          content,
          dialogue:      (beat_type == "dialogue" ? content : nil),
          notes:         notes,
          is_active:     true
        }

        action_beat = ActionBeat.new(ab_attrs)
        if action_beat.save
          beat_numbers.add(beat_number)

          # Associate characters with this beat
          import_beat_characters(beat_chars, action_beat)

          Rails.logger.debug "[ScriptJsonImporter] ✅ Created action beat #{beat_number} for scene #{scene_record.number}"
        else
          Rails.logger.error "[ScriptJsonImporter] ✗ ActionBeat #{scene_record.number}.#{beat_number} save failed: #{action_beat.errors.full_messages.join(', ')}"
        end

      rescue => e
        Rails.logger.error "[ScriptJsonImporter] ✗ Error creating action beat #{idx + 1} in scene #{scene_record.number}: #{e.class}: #{e.message}"
      end
    end
  end

  def normalize_beat_type(type_str)
    normalized = type_str.to_s.downcase.strip
    case normalized
    when "dialogue", "dialog"
      "dialogue"
    when "action"
      "action"
    else
      Rails.logger.warn "[ScriptJsonImporter] ⚠️ Unknown beat type '#{type_str}', defaulting to 'action'"
      "action"
    end
  end

  def import_beat_characters(beat_chars, action_beat)
    return unless beat_chars.is_a?(Array)

    beat_chars.each do |raw_name|
      name = clean_character_name(raw_name)
      next if name.blank?

      begin
        create_character_and_appearance(name, scene: nil, action_beat: action_beat)
      rescue => e
        Rails.logger.error "[ScriptJsonImporter] ✗ Failed to create character appearance for '#{name}' in action beat: #{e.message}"
      end
    end
  end

  def clean_character_name(raw_name)
    return nil if raw_name.blank?

    name = raw_name.to_s.strip

    # Remove common character formatting
    name = name.gsub(/\A(CHARACTER|CHAR)[\s:]*/, '')  # Remove "CHARACTER:" prefix
    name = name.gsub(/[\(\)]+/, '')                   # Remove parentheses
    name = name.gsub(/\s+/, ' ')                      # Normalize whitespace

    # Return nil if name is too short or contains only special characters
    return nil if name.length < 2 || name.match?(/\A[^a-zA-Z]*\z/)

    name
  end

  def create_character_and_appearance(name, scene:, action_beat:)
    name_key = name.downcase

    # Find or create character
    character = @created_characters[name_key]
    unless character
      character = Character.find_by(full_name: name, production_id: @production.id)
      unless character
        character = Character.create!(
          full_name: name,
          production_id: @production.id
        )
        Rails.logger.debug "[ScriptJsonImporter] 📝 Created character: #{name}"
      end
      @created_characters[name_key] = character
    end

    # Create character appearance
    ca_attrs = { character_id: character.id }
    if scene
      ca_attrs[:scene_id] = scene.id
    elsif action_beat
      ca_attrs[:action_beat_id] = action_beat.id
    else
      Rails.logger.warn "[ScriptJsonImporter] ⚠️ No scene or action_beat provided for character appearance"
      return
    end

    # Check for existing appearance to prevent duplicates
    existing = CharacterAppearance.find_by(ca_attrs)
    unless existing
      CharacterAppearance.create!(ca_attrs)
    end

  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "[ScriptJsonImporter] ✗ CharacterAppearance failed for '#{name}': #{e.record.errors.full_messages.join(', ')}"
  rescue ActiveRecord::RecordNotUnique => e
    Rails.logger.debug "[ScriptJsonImporter] ℹ️ Duplicate character appearance for '#{name}' (already exists)"
  end

  def map_int_ext(raw)
    return nil if raw.blank?

    # Clean and normalize the input
    cleaned = raw.to_s.upcase.strip.gsub(/\.$/, '')  # Remove trailing period

    case cleaned
    when /\AINT\z/, /\AINTERNAL\z/
      "interior"
    when /\AEXT\z/, /\AEXTERNAL\z/, /\AEXTERIOR\z/
      "exterior"
    when /\AINT[\s\/]*EXT\z/, /\AEXT[\s\/]*INT\z/, /\AINTERNAL[\s\/]*EXTERNAL\z/
      "interior"  # Default mixed to interior
    else
      # Try to detect based on common patterns
      if cleaned.include?("INT")
        "interior"
      elsif cleaned.include?("EXT")
        "exterior"
      else
        Rails.logger.warn "[ScriptJsonImporter] ⚠️ Could not parse int_ext: '#{raw}'"
        nil
      end
    end
  end
end
