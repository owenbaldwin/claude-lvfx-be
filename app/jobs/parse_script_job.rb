# app/jobs/parse_script_job.rb
require 'pdf/reader'
require "ruby/openai"

class ParseScriptJob < ApplicationJob
  queue_as :default

  def perform(production_id, script_id)
    script = Script.find(script_id)

    # 1) download the PDF from ActiveStorage
    pdf_data = script.file.download

    # 2) extract plain text
    reader   = PDF::Reader.new(StringIO.new(pdf_data))
    raw_text = reader.pages.map(&:text).join("\n\n")

    prompt = <<~PROMPT


      You are a script‐analysis assistant. You will receive the full text of a film script. Your job is to extract **only the actual scene headings (sluglines)** and return them as valid JSON with **two separate fields**:

        1. `"index"`: a strictly sequential integer starting at 1 and incrementing by 1 for each extracted slugline, **regardless of the scene’s printed number**.
        2. `"text"`: the exact scene heading as it appears in the script, including any alphanumeric suffix (e.g. “3A”, “34B”), without alteration.

      **Output JSON format (no extra text, no commentary):**
      ```json
      {
        "scenes": [
          { "index": 1, "text": "1 INT. HOUSE – DAY" },
          { "index": 2, "text": "2 EXT. GARDEN – DAY" },
          { "index": 3, "text": "3A INT. GARDEN SHED – DAY" },
          { "index": 4, "text": "3B INT. GARDEN SHED – NIGHT" },
          { "index": 5, "text": "4 INT. HOUSE – DAY" }
          // …etc.
        ]
      }
      Strict Rules

      Preserve the scene number exactly as it appears in the script.

      If the script shows “3A INT. LOCATION TIME”, then "text" must begin with "3A".

      If the script shows “34B EXT. LOCATION NIGHT”, then "text" must begin with "34B".

      Do not strip away or renumber any lettered suffix.

      Use "index" only to count sequentially, starting at 1.

      The first slugline seen → "index": 1; second slugline → "index": 2; and so on.

      Do not tie "index" to the numeric part of the scene heading.

      If a slugline repeats with “CONT’D” or “CONTINUED,” ignore that repeat; it is not a new scene.

      Only extract lines that are valid sluglines—lines that begin with either:

      a scene number (e.g. “1 ”, “2 ”, “3A ”, “10B ”, etc.)

      or “INT.”, “EXT.”, or “INT./EXT.” (in case the script omitted a printed number).

      Each extracted slugline must match the pattern:


      [scene number (digits, possibly followed by a letter)] [INT./EXT./INT./EXT.] [LOCATION] [TIME OF DAY]
      Examples:

      “3 INT. OFFICE – NIGHT”

      “3A EXT. ALLEYWAY – DAY”

      “10B INT./EXT. CAR – DAY”

      Return only valid JSON—no extra quotes, no markdown fences, and no explanatory text.

      If the script’s sluglines are uppercase or lowercase, preserve the original casing exactly.

      Do not invent or hallucinate any sluglines. Only extract those that actually appear in the provided text.

      Make sure you go all the way to the end of the script. Do not cut off at any point until you have reached the end of the script.

      If a scene has a number and a letter, then the letter is part of the scene number. Include the letter in the scene number. This means that the scene number will be different that the index value for that object. Do not let this confuse you. If for instance the script shows “3A INT. LOCATION TIME”, then the scene number is 3A, not 3. Its index value is 3. If the next scene is “3B INT. LOCATION TIME”, then its scene number is 3B, not 3. Its index value is 4. If the next scene is “4 INT. LOCATION TIME”, then its scene number is 4. Its index value is 5. Index values are to be unique and sequential, always incrementing by 1. Do so until you have reached the end of the script.


      =====
      #{raw_text}
    PROMPT

    client   = OpenAI::Client.new(
      access_token: ENV.fetch("OPENAI_API_KEY"),
    request_timeout: 300)
    # response = client.chat(
    #   parameters: {
    #     model: "gpt-4",
    #     messages: [{ role: "user", content: prompt }]
    #   }
    # )
    # response = client.chat(
    #   parameters: {
    #     model: "gpt-3.5-turbo-16k",            # ← smaller-cost 16 K-token window
    #     messages: [{ role: "user", content: prompt }]
    #   }
    # )
    response = client.chat(
      parameters: {
        model: "gpt-4.1-nano-2025-04-14",                    # ← full GPT-4 with 32 K window
        messages: [{ role: "user", content: prompt }],
        max_tokens: 32768,
        temperature: 0
      }
    )
    # response = client.chat(
    #   parameters: {
    #     model: "o4-mini-2025-04-16",  # ← o4-mini endpoint
    #     messages: [{ role: "user", content: prompt }],
    #     max_completion_tokens: 100_000,
    #   }
    # )

    # Dump the entire JSON to your logs
    Rails.logger.info "🤖 GPT-4 raw response for Script##{script_id}: #{response.to_json}"

    # Then you can still pull out the part you care about
    content = response.dig("choices",0,"message","content")
    Rails.logger.info "🤖  Content: #{content.inspect}"



    sluglines_json = response.dig("choices",0,"message","content")
    Rails.logger.info "[ParseScriptJob] → #{sluglines_json}"
  rescue => e
    Rails.logger.error "[ParseScriptJob] ✗ #{e.class}: #{e.message}"
    raise
  end
end
