# app/jobs/parse_script_job.rb
require 'pdf/reader'
require 'json'
require 'thread'        # for Mutex
require "ruby/openai"

class ParseScriptJob < ApplicationJob
  queue_as :default

  def perform(production_id, script_id)
    script   = Script.find(script_id)
    pdf_data = script.file.download

    # 1) Read entire PDF → raw_text
    reader   = PDF::Reader.new(StringIO.new(pdf_data))
    raw_text = reader.pages.map(&:text).join("\n\n")

    # 2) First GPT call: extract sluglines JSON as before...
    sluglines_prompt = <<~PROMPT
      You are a script‐analysis assistant. You will receive the full text of a film script.
      Your job is to extract only the actual scene headings (sluglines) and return them as valid JSON
      with two fields:

        1. "index": a strictly sequential integer starting at 1 and incrementing by 1 for each extracted slugline,
           regardless of the scene's printed number.
        2. "text": the exact scene heading as it appears in the script, including any alphanumeric suffix ("3A", "10B", etc.), without alteration.

      Output JSON format, no extra text:
      {
        "scenes": [
          { "index": 1, "text": "1 INT. HOUSE – DAY" },
          { "index": 2, "text": "2 EXT. GARDEN – DAY" },
          …
        ]
      }

      Strict rules:
      • Preserve printed scene numbers and any letter suffix (e.g. "3A"). Do not renumber or strip suffixes.
      • Use "index" only for counting 1, 2, 3, … in order of appearance.
      • If you see "3A INT. LOCATION – NIGHT" then text must begin with "3A".
      • Ignore "CONT'D" or "CONTINUED" repeats of the same slugline.
      • Only extract lines that begin with either:
        a) a scene number (digits, possibly followed by a letter), or
        b) "INT.", "EXT.", or "INT./EXT." (if the script omits a printed number).
      • Each extracted line must match the pattern:
        [scene number][space][INT./EXT./INT./EXT.][space][LOCATION][space "–" space][TIME]
        e.g. "3A EXT. ALLEYWAY – DAY" or "10B INT./EXT. CAR – NIGHT".
      • Preserve original casing and spacing exactly.
      • Do not invent or hallucinate sluglines; only extract what appears in the provided text.
      • Process the entire script until the very end.

      =====
      #{raw_text}
    PROMPT

    client = OpenAI::Client.new(
      access_token: ENV.fetch("OPENAI_API_KEY"),
      request_timeout: 300
    )

    slug_response = client.chat(
      parameters: {
        model:       "gpt-4.1-nano-2025-04-14",
        messages:    [{ role: "user", content: sluglines_prompt }],
        max_tokens:  32_768,
        temperature: 0
      }
    )

    Rails.logger.info "🤖 GPT‐4 raw slugline response for Script##{script_id}: #{slug_response.to_json}"

    # Extract the JSON text from the assistant's reply
    sluglines_json = slug_response.dig("choices", 0, "message", "content")
    unless sluglines_json.is_a?(String) && sluglines_json.strip.start_with?("{")
      Rails.logger.error "[ParseScriptJob] ✗ Unexpected sluglines output: #{sluglines_json.inspect}"
      return
    end

    parsed     = JSON.parse(sluglines_json)
    all_scenes = parsed.fetch("scenes")   # => [ { "index" => 1, "text" => "1 EXT.…" }, … ]

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

    all_indices.each do |idx|
      slug            = index_to_slug[idx]
      normalized_slug = normalize_for_matching(slug)

      found_pos = nil

      # 1) Try exact‐line matching after normalization
      raw_lines.each do |line|
        if normalize_for_matching(line) == normalized_slug
          found_pos = raw_text.index(line)
          break
        end
      end

      # 2) If still nil, try "sceneNumber + first word of location" match
      if found_pos.nil?
        parts = slug.strip.split(/\s+/, 3)
        if parts.size == 3
          scene_num, int_ext, location_rest = parts
          norm_num  = normalize_for_matching(scene_num)
          norm_loc1 = normalize_for_matching(location_rest).split(" ").first
          raw_lines.each do |line|
            nl = normalize_for_matching(line)
            if nl.include?(norm_num) && nl.include?(norm_loc1)
              found_pos = raw_text.index(line)
              break
            end
          end
        end
      end

      # 3) If still nil, fall back to a \s+‐style regex
      if found_pos.nil?
        re_str = normalized_slug
                .gsub(/[-]/, "\\-")    # escape hyphens for the regex
                .gsub(/\s+/, "\\s+")   # run of spaces in slug → \s+
        regex = /#{re_str}/i
        match_data = raw_text.match(regex)
        found_pos = match_data.begin(0) if match_data
      end

      if found_pos.nil?
        Rails.logger.error "[ParseScriptJob] ✗ Could not locate slugline '#{slug}' in raw_text"
        slug_offset_map[idx] = 0
      else
        slug_offset_map[idx] = found_pos
      end
    end

    # 6) Group indices into 4 buckets for concurrent processing
    buckets = {0 => [], 1 => [], 2 => [], 3 => []}
    all_indices.each { |idx| buckets[(idx - 1) % 4] << idx }

    # 7) Shared structures for thread‐safe results
    scene_results = {}           # idx => parsed_scene_hash
    results_mutex = Mutex.new

    # 8) Helper: build per‐scene prompt
    def build_scene_detail_prompt(scene_chunk, start_slug, until_slug, index)
      <<~PROMPT
        You are a script‐analysis assistant. You will receive:

        1) The full text of a single scene (from one slugline up to—but not including—the next).
        2) A "start from" slugline that exactly marks the beginning of Scene #{index}.
        3) An "until" slugline that exactly marks the beginning of the next scene (i.e. the stop marker).

        Your job is to extract **only** the contents belonging to Scene #{index}. Treat everything from "#{start_slug}"
        up until—but not including—the line "#{until_slug}" as the entire scene text.

        You must return exactly **one JSON object** (no extra text, no markdown fences). Fields:

        {
          "scene_index": #{index},
          "scene_number": <number>,
          "int_ext": "INT. or EXT.",
          "location": "scene location",
          "time": "scene time of day",
          "extra": "extra information about the scene like CONT'D etc if present",
          "description": "brief description of the scene",
          "characters": [
            "character name 1",
            "character name 2"
          ],
          "action_beats": [
            {
              "type": "action or dialogue",
              "characters": [
                "character name 1",
                "character name 2"
              ],
              "indications": "(e.g., O.S., V.O.) if applicable",
              "content": "text of the action or dialogue"
            }
            // …more beats…
          ]
        }



        RULES:
        • Preserve original casing/spaces. Do not alter or strip anything.
        • Do not include any lines from the "until" slugline onward—you only have scene_chunk.
        • If the scene has no dialogue, return "dialogues": [] and still list characters: [].
        • If the scene has no action, return "actions": [].
        • The JSON must parse as valid JSON. Do not output any commentary.
        • Preserve any parentheticals (e.g. `(whispering)`) in the "line".

        ======
        SCENE TEXT:
        #{scene_chunk}
      PROMPT
    end

    # 9) Spawn 4 threads (one per bucket_key = 0..3)
    threads = []

    4.times do |bucket_key|
      threads << Thread.new do
        buckets[bucket_key].sort.each do |scene_index|
          start_slug = index_to_slug.fetch(scene_index)
          until_slug = index_to_until_slug.fetch(scene_index)

          # 9a) Compute start_pos & end_pos in raw_text
          start_pos = slug_offset_map[scene_index]
          if start_pos.nil? || start_pos == 0
            Rails.logger.warn "[ParseScriptJob] ⚠️ Using fallback start_pos=0 for scene #{scene_index}"
          end

          end_pos = if until_slug == "END OF SCRIPT"
                      raw_text.length
                    else
                      # Locate the next slugline in a whitespace‐normalized way:
                      next_slug      = until_slug.strip.gsub(/\s+/, " ")
                      found_end_pos  = nil
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
            next
          end

          prompt = build_scene_detail_prompt(scene_chunk, start_slug, until_slug, scene_index)

          # 9b) Call OpenAI with a retry loop
          raw_content  = nil
          retries_left = 2

          begin
            response = client.chat(
              parameters: {
                model:       "gpt-4.1-nano-2025-04-14",
                messages:    [{ role: "user", content: prompt }],
                max_tokens:  16_384,
                temperature: 0
              }
            )

            Rails.logger.info "[ParseScriptJob] 📝 Scene #{scene_index} API response received"

            # Extract content from response - ruby-openai gem returns response directly as hash
            raw_content = response.dig("choices", 0, "message", "content")

            if raw_content.blank?
              Rails.logger.error "[ParseScriptJob] ✗ Scene #{scene_index} returned empty content"
              next   # skip this scene_index entirely
            end

            # 9c) Try to parse that JSON for the first time
            parsed_scene = JSON.parse(raw_content)

          rescue JSON::ParserError => parse_err
            Rails.logger.error "[ParseScriptJob] ✗ JSON parse failed for scene #{scene_index}: #{parse_err.message}"
            Rails.logger.error "→ raw_content was: #{raw_content.inspect}"

            #  If it was malformed, ask GPT to "just fix the missing brace/bracket"
            retry_prompt = <<~TXT
              The JSON you returned (for scene #{scene_index}) was:
              #{raw_content}

              It looks like you may have truncated the closing braces or square brackets, making it invalid JSON.
              Please return **only** the corrected JSON object (with keys "index", "scene_number", "location", "time_of_day", "characters", "actions", "dialogues") by adding the missing `}` or `]`. Do not change any other content.
            TXT

            begin
              fix_response = client.chat(
                parameters: {
                  model:       "gpt-4.1-nano-2025-04-14",
                  messages:    [{ role: "user", content: retry_prompt }],
                  max_tokens:  1_000,
                  temperature: 0
                }
              )

              # Extract fixed content from response
              fixed_content = fix_response.dig("choices", 0, "message", "content")

              if fixed_content.present?
                parsed_scene = JSON.parse(fixed_content)
                Rails.logger.info "[ParseScriptJob] ✅ JSON fix successful for scene #{scene_index}"
              else
                Rails.logger.error "[ParseScriptJob] ✗ Fix response empty for scene #{scene_index}"
                next
              end
            rescue JSON::ParserError => e2
              Rails.logger.error "[ParseScriptJob] ✗ JSON still invalid after retry for scene #{scene_index}: #{e2.message}"
              Rails.logger.error "→ fixed attempt: #{fixed_content.inspect}"
              next   # skip this scene_index entirely
            rescue => fix_error
              Rails.logger.error "[ParseScriptJob] ✗ Fix API call failed for scene #{scene_index}: #{fix_error.class}: #{fix_error.message}"
              next
            end

          rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Net::ReadTimeout => e
            if retries_left > 0
              retries_left -= 1
              Rails.logger.warn "[ParseScriptJob] ⚠️ Network error for scene #{scene_index}, retrying (#{retries_left} left): #{e.class}"
              sleep(2 + rand(3)) # Add some jitter to avoid thundering herd
              retry
            else
              Rails.logger.error "[ParseScriptJob] ✗ Network failed twice for scene #{scene_index}: #{e.class}: #{e.message}"
              next   # skip this scene_index entirely
            end
          rescue => e
            Rails.logger.error "[ParseScriptJob] ✗ Unexpected error for scene #{scene_index}: #{e.class}: #{e.message}"
            Rails.logger.error e.backtrace.join("\n")
            next   # skip this scene_index entirely
          end

          # 9d) If we got a valid parsed_scene, store it
          if parsed_scene
            results_mutex.synchronize do
              scene_results[scene_index] = parsed_scene
            end
            Rails.logger.info "[ParseScriptJob] ✅ Scene #{scene_index} parsed successfully"
          end
        end
      end
    end

    # 10) Wait for threads to finish
    threads.each(&:join)

    # 11) Build final sorted array
    final_array = all_indices.map do |idx|
      if scene_results.key?(idx)
        scene_results[idx]
      else
        { "index" => idx, "error" => "parsing_failed_or_missing" }
      end
    end

    final_payload = { "scenes" => final_array }
    Rails.logger.info "[ParseScriptJob] 🏁 Final combined scenes JSON for Script##{script_id}: #{JSON.pretty_generate(final_payload)}"

    # Optionally save:
    # script.update!(scenes_data_json: final_payload.to_json)

  rescue => e
    Rails.logger.error "[ParseScriptJob] ✗ #{e.class}: #{e.message}"
    raise
  end
end
