# app/services/script_json_importer.rb

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
    # @sequence   = script.sequence
    @json_data  = script.scenes_data_json || {}   # expecting {"scenes"=>[ ... ]}
    @created_characters = {}  # key: downcased name, value: Character record
  end

  def import!
    unless @script.scenes_data_json.is_a?(Hash) && @script.scenes_data_json["scenes"].is_a?(Array)
      raise "No valid JSON found on script.scenes_data_json"
    end

    ActiveRecord::Base.transaction do
      import_scenes
    end
    Rails.logger.info "[ScriptJsonImporter] ✅ Import succeeded for Script##{@script.id}"
  rescue => e
    Rails.logger.error "[ScriptJsonImporter] ✗ Import failed for Script##{@script.id}: #{e.class}: #{e.message}"
    raise
  end

  private

  def import_scenes
    # The JSON array is something like:
    #   [ { "scene_index"=>1, "scene_number"=>1, "int_ext"=>"INT.", "location"=>"HOUSE", "time"=>"DAY",
    #       "extra"=>"(CONT'D)", "description"=>"…",
    #       "characters"=>["BOB","ALICE"],
    #       "action_beats"=>[ { "type"=>"action", "characters"=>["BOB"], "indications"=>"(O.S.)", "content"=>"Bob walks in." }, … ]
    #     }, …
    #   ]

    @json_data.fetch("scenes", []).each do |scene_hash|
      scene_record = create_scene_from_json(scene_hash)
      next unless scene_record&.persisted?

      import_scene_level_characters(scene_hash.fetch("characters", []), scene_record)
      import_action_beats(scene_hash.fetch("action_beats", []), scene_record)
    end
  end

  def create_scene_from_json(scene_hash)
    # Extract fields (JSON keys are strings):
    scene_number = scene_hash.fetch("scene_number").to_i
    raw_int_ext  = scene_hash.fetch("int_ext").strip       # e.g. "INT." or "EXT."
    location     = scene_hash.fetch("location").strip
    time_of_day  = scene_hash.fetch("time").strip          # e.g. "DAY", "NIGHT"
    description  = scene_hash.fetch("description", nil)
    extra_info   = scene_hash.fetch("extra", nil)          # e.g. "(CONT'D)" or nil

    # Map raw_int_ext into "interior" / "exterior"
    int_ext_mapped = map_int_ext(raw_int_ext)

    # Build a name (optional—you can customize):
    scene_name = "#{raw_int_ext} #{location} – #{time_of_day}"
    scene_attrs = {
      production_id: @production.id,
      script_id:     @script.id,
      number:        scene_number,
      int_ext:       int_ext_mapped,
      location:      location,
      day_night:     time_of_day.downcase,   # your validation wants presence; adjust case as desired
      name:          scene_name,
      description:   description,
      is_active:     true
      # version_number + source_scene_id are handled by Scene callbacks
    }

    scene = Scene.new(scene_attrs)
    unless scene.save
      Rails.logger.error "[ScriptJsonImporter] ✗ Scene##{scene_number} save failed: #{scene.errors.full_messages.join(', ')}"
    end

    scene
  end

  def import_scene_level_characters(character_names, scene_record)
    # For each name in JSON["characters"], create/find Character, then one CharacterAppearance(scene: scene_record).
    character_names.each do |raw_name|
      name = raw_name.to_s.strip
      next if name.blank?

      create_character_and_appearance(name, scene: scene_record, action_beat: nil)
    end
  end

  def import_action_beats(action_beats_array, scene_record)
    # JSON action_beats is [ { "type"=>"action"/"dialogue", "characters"=>[...], "indications"=>"(O.S.)", "content"=>"…" }, … ]
    action_beats_array.each_with_index do |beat_hash, idx|
      line_number = idx + 1
      beat_type   = beat_hash.fetch("type").strip.downcase    # expecting "action" or "dialogue"
      content     = beat_hash.fetch("content", "").strip
      notes       = beat_hash["indications"]                  # may be nil
      beat_chars  = beat_hash.fetch("characters", [])

      ab_attrs = {
        scene_id:      scene_record.id,
        production_id: @production.id,
        script_id:     @script.id,
        number:        line_number,
        beat_type:     beat_type,
        text:          content,
        dialogue:      (beat_type == "dialogue" ? content : nil),
        notes:         notes,
        is_active:     true
        # version_number + source_beat_id come from callbacks
      }

      action_beat = ActionBeat.new(ab_attrs)
      unless action_beat.save
        Rails.logger.error "[ScriptJsonImporter] ✗ ActionBeat #{scene_record.number}.#{line_number} save failed: #{action_beat.errors.full_messages.join(', ')}"
        next
      end

      # associate each character on this beat
      beat_chars.each do |raw_name|
        name = raw_name.to_s.strip
        next if name.blank?
        create_character_and_appearance(name, scene: nil, action_beat: action_beat)
      end
    end
  end

  def create_character_and_appearance(raw_name, scene:, action_beat:)
    name_key = raw_name.downcase

    character = @created_characters[name_key] ||
                Character.find_by(full_name: raw_name, production_id: @production.id)

    unless character
      character = Character.create!(
        full_name:     raw_name,
        production_id: @production.id
      )
    end

    @created_characters[name_key] = character

    ca_attrs = { character_id: character.id }
    if scene
      ca_attrs[:scene_id] = scene.id
    elsif action_beat
      ca_attrs[:action_beat_id] = action_beat.id
    else
      return
    end

    CharacterAppearance.create!(ca_attrs)
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "[ScriptJsonImporter] ✗ CharacterAppearance failed for '#{raw_name}': #{e.record.errors.full_messages.join(', ')}"
  end

  def map_int_ext(raw)
    # raw examples: "INT.", "EXT.", "INT./EXT."
    case raw.upcase
    when /\AINT\.?\z/
      "interior"
    when /\AEXT\.?\z/
      "exterior"
    when /\AINT\.?\/EXT\.?\z/, /\AEXT\.?\/INT\.?\z/
      "interior"
    else
      raw.upcase.start_with?("INT") ? "interior" : "exterior"
    end
  end
end
