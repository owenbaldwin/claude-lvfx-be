require 'json'
require 'thread'
require "ruby/openai"

class GenerateShotsJob < ApplicationJob
  queue_as :default

  def perform(user_id, action_beat_ids, shot_generation_id)
    shot_generation = ShotGeneration.find(shot_generation_id)

    begin
      Rails.logger.info "[GenerateShotsJob] Starting job for user #{user_id} with action_beat_ids: #{action_beat_ids}"

      # Update status to processing
      shot_generation.update!(status: 'processing')

      # Get shots_per_beat from shot_generation results_json, default to 1
      shots_per_beat = shot_generation.results_json&.dig('shots_per_beat') || 1

      Rails.logger.info "[GenerateShotsJob] shots_per_beat = #{shots_per_beat}"

      # Load action beats with necessary associations
      beats = ActionBeat.includes(:scene, character_appearances: :character)
                        .find(action_beat_ids)

      Rails.logger.info "[GenerateShotsJob] Loaded #{beats.count} action beats"

      # Build beats data array
      beats_data = beats.map do |beat|
        characters = beat.character_appearances.map { |ca| ca.character.full_name }.compact

        {
          id: beat.id,
          type: beat.beat_type,
          content: beat.text,
          scene_context: beat.scene.description || "No scene description",
          characters: characters
        }
      end

      Rails.logger.info "[GenerateShotsJob] Built beats data for #{beats_data.count} beats"

      # Construct batched prompt
      prompt = build_shots_prompt(beats_data, shots_per_beat)

      Rails.logger.info "[GenerateShotsJob] Generated prompt with shots_per_beat: #{shots_per_beat}"
      Rails.logger.debug "[GenerateShotsJob] Full prompt: #{prompt}"

      # Initialize OpenAI client
      client = OpenAI::Client.new(
        access_token: ENV.fetch("OPENAI_API_KEY"),
        request_timeout: 300
      )

      Rails.logger.info "[GenerateShotsJob] Calling OpenAI API"

      # Call OpenAI API with retry logic
      raw_json = nil
      retries_left = 2

      begin
        response = client.chat(
          parameters: {
            model: "gpt-4.1-nano-2025-04-14",
            messages: [{ role: "user", content: prompt }],
            max_tokens: 32768,
            temperature: 0
          }
        )

        Rails.logger.info "[GenerateShotsJob] Received OpenAI response"
        raw_json = response.dig("choices", 0, "message", "content")

        if raw_json.blank?
          raise StandardError, "Empty response from OpenAI"
        end

      rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Net::ReadTimeout => e
        if retries_left > 0
          retries_left -= 1
          Rails.logger.warn "[GenerateShotsJob] ⚠️ Network error, retrying (#{retries_left} left): #{e.class}"
          sleep(2 + rand(3)) # Add jitter
          retry
        else
          raise StandardError, "Network failed after retries: #{e.class}: #{e.message}"
        end
      end

      # Parse JSON response
      parsed = nil
      begin
        parsed = JSON.parse(raw_json)
        Rails.logger.info "[GenerateShotsJob] Successfully parsed JSON response"
        Rails.logger.debug "[GenerateShotsJob] Parsed response: #{parsed.inspect}"
      rescue JSON::ParserError => parse_err
        Rails.logger.error "[GenerateShotsJob] ✗ JSON parse failed: #{parse_err.message}"
        Rails.logger.error "→ raw_content was: #{raw_json.inspect}"

        # Try to fix JSON with retry prompt
        retry_prompt = <<~TXT
          The JSON you returned was:
          #{raw_json}

          It looks like you may have truncated the closing braces or square brackets, making it invalid JSON.
          Please return **only** the corrected JSON object with all action beat IDs as keys, each mapping to an array of shot objects with "description" field. Do not change any other content.
        TXT

        begin
          fix_response = client.chat(
            parameters: {
              model: "gpt-4.1-nano-2025-04-14",
              messages: [{ role: "user", content: retry_prompt }],
              max_tokens: 32768,
              temperature: 0
            }
          )

          fixed_content = fix_response.dig("choices", 0, "message", "content")
          if fixed_content.present?
            parsed = JSON.parse(fixed_content)
            Rails.logger.info "[GenerateShotsJob] ✅ JSON fix successful"
          else
            raise StandardError, "Fix response empty"
          end
        rescue JSON::ParserError => e2
          raise StandardError, "JSON still invalid after retry: #{e2.message}"
        rescue => fix_error
          raise StandardError, "Fix API call failed: #{fix_error.class}: #{fix_error.message}"
        end
      end

      # Create shots from parsed response
      results_mutex = Mutex.new
      created_shots_count = 0
      created_shots_data = {}

      Rails.logger.info "[GenerateShotsJob] Creating shots from parsed response"

      parsed.each do |beat_id_str, shots_array|
        beat_id = beat_id_str.to_i
        beat = beats.find { |b| b.id == beat_id }

        unless beat
          Rails.logger.warn "[GenerateShotsJob] ⚠️ Could not find beat with id #{beat_id}"
          next
        end

        unless shots_array.is_a?(Array)
          Rails.logger.warn "[GenerateShotsJob] ⚠️ Shots for beat #{beat_id} is not an array: #{shots_array.inspect}"
          next
        end

        Rails.logger.info "[GenerateShotsJob] Processing beat #{beat_id} with #{shots_array.length} shots"

        beat_shots = []

        # Find the next shot number for this action beat ONCE before the loop
        max_shot_number = Shot.where(action_beat_id: beat_id).maximum(:number) || 0

        shots_array.each_with_index do |shot_data, index|
          unless shot_data.is_a?(Hash) && shot_data["description"].present?
            Rails.logger.warn "[GenerateShotsJob] ⚠️ Invalid shot data for beat #{beat_id}: #{shot_data.inspect}"
            next
          end

          begin
            # Calculate shot number based on the initial max + index
            shot_number = max_shot_number + index + 1

            shot = Shot.create!(
              action_beat_id: beat_id,
              scene_id: beat.scene_id,
              sequence_id: beat.sequence_id,
              production_id: beat.production_id,
              script_id: beat.script_id,
              number: shot_number,
              description: shot_data["description"],
              camera_angle: "",
              camera_movement: "",
              vfx: "no",
              is_active: true,
              version_number: 1
            )

            beat_shots << {
              id: shot.id,
              number: shot.number,
              description: shot.description
            }

            results_mutex.synchronize { created_shots_count += 1 }
            Rails.logger.debug "[GenerateShotsJob] Created shot #{shot_number} for beat #{beat_id}"

          rescue => e
            Rails.logger.error "[GenerateShotsJob] ✗ Failed to create shot for beat #{beat_id}: #{e.class}: #{e.message}"
            next
          end
        end

        created_shots_data[beat_id] = beat_shots
      end

      Rails.logger.info "[GenerateShotsJob] ✅ Job completed successfully. Created #{created_shots_count} shots"

      # Update shot_generation with successful results, preserving original data
      original_data = shot_generation.results_json || {}
      shot_generation.update!(
        status: 'completed',
        results_json: original_data.merge({
          shots_created: created_shots_count,
          shots_by_beat: created_shots_data,
          completed_at: Time.current
        })
      )

    rescue => e
      Rails.logger.error "[GenerateShotsJob] ✗ Job failed: #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Update shot_generation with error
      shot_generation.update!(
        status: 'failed',
        error: "#{e.class}: #{e.message}"
      )

      raise
    end
  end

  private

  def build_shots_prompt(beats_data, shots_per_beat)
    beats_summary = beats_data.map do |beat|
      <<~BEAT
        Beat ID: #{beat[:id]}
        Type: #{beat[:type]}
        Content: #{beat[:content]}
        Scene Context: #{beat[:scene_context]}
        Characters: #{beat[:characters].join(', ')}
      BEAT
    end.join("\n---\n")

    <<~PROMPT
      You are a professional cinematographer and film production assistant. You will receive information about action beats from a film script, and your job is to generate creative and technically sound shot ideas for each beat.

      For each action beat provided, generate exactly #{shots_per_beat} distinct shot ideas that would effectively capture the content and emotion of that beat. Consider:
      - The type of beat (action vs dialogue)
      - The characters involved
      - The scene context
      - Cinematic storytelling principles
      - Visual variety and coverage

      Here are the action beats to analyze:

      #{beats_summary}

      Return exactly one JSON object with keys equal to the beat IDs (as strings), where each key maps to an array of exactly #{shots_per_beat} shot objects. Each shot object must have a "description" field containing a detailed description of the shot.

      Example format:
      {
        "123": [
          #{(1..shots_per_beat).map { |i| '{"description": "Shot description ' + i.to_s + '"}' }.join(",\n          ")}
        ]
      }

      Make each shot description specific, actionable, and cinematically interesting. Include camera angles, shot sizes, and any notable camera movements or techniques where appropriate.
    PROMPT
  end
end
