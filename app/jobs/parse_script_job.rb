# app/jobs/parse_script_job.rb
require "pdf/reader"
require "net/http"
require "uri"
require "json"

class ParseScriptJob < ApplicationJob
  queue_as :default

  OPENAI_BASE_URL = "https://api.openai.com"

  def perform(production_id, script_id)
    script = Script.find(script_id)

     # ── Extract raw_text from the attached PDF before anything else ──
    unless script.file.attached?
      raise "No PDF attached to Script##{script_id}"
    end

    # (1) Download PDF bytes from ActiveStorage
    pdf_bytes = script.file.download

    # (2) Build a PDF::Reader over those bytes
    reader = PDF::Reader.new(StringIO.new(pdf_bytes))

    # (3) Concatenate all pages’ plain text into one String
    raw_text = reader.pages.map(&:text).join("\n")


    system_prompt = <<~SYSMSG.chomp
      You are a script‐analysis assistant. You will receive the full text of a film script.
      Your job is to extract only the actual scene headings (sluglines) and return them as valid JSON
      with two separate fields:

        1. "index": a strictly sequential integer starting at 1 and incrementing by 1
           for each extracted slugline, regardless of the scene’s printed number.
        2. "text": the exact scene heading as it appears in the script, including any alphanumeric suffix
           (e.g. "3A", "34B"), without alteration.

      Output JSON format (no extra text, no commentary):
      {
        "scenes": [
          { "index": 1, "text": "1 INT. HOUSE – DAY" },
          { "index": 2, "text": "2 EXT. GARDEN – DAY" },
          // …etc.
        ]
      }

      Strict Rules: (…all your rules here…)
      Make sure you go all the way to the end of the script. …
    SYSMSG

    #
# === 3) Create the assistant under /v1/assistants with "assistants=v2" header ===
#
assistant_payload = {
  name:         "script-slugline-extractor-#{script_id}",
  description:  "Loads a full script and returns JSON of scene sluglines",
  model:        "gpt-4o-mini",
  instructions: system_prompt
}


assistant_resp = openai_request(
  method: :post,
  path:   "/v1/assistants",        # keep /v1 here
  body:   assistant_payload
)
# assistant_id = assistant_resp.dig("assistant", "assistant_id")
# assistant_id = assistant_resp.dig("assistant", "id")
assistant_id = assistant_resp.dig("id")

Rails.logger.info "[ParseScriptJob] → Created assistant #{assistant_id}"

    #
    # === 4) Create a thread under that assistant (POST /v1/threads) ===
    #
    # thread_resp = openai_request(
    #   method: :post,
    #   path:   "/v1/threads",         # keep /v1 here
    #   body:   nil   # or omit `body:` altogether
    # )

    # # thread_id = thread_resp.dig("thread", "thread_id")
    # # thread_id = thread_resp.dig("thread", "id")
    # thread_id = thread_resp.dig("id")
    # Rails.logger.info "[ParseScriptJob] → Created thread #{thread_id}"
    # Corrected “create thread”:
    thread_resp = openai_request(
      method: :post,
      path:   "/v1/threads",
      body:   nil
    )
    thread_id = thread_resp.dig("id")   # ← not dig("thread","id")
    Rails.logger.info "[ParseScriptJob] → Created thread #{thread_id}"


    #
    # === 5) Send the entire raw script as a “user” message ===
    #
    load_script_msg = <<~LOADMSG
      LOAD_SCRIPT:
      #{raw_text}
    LOADMSG

    # openai_request(
    #   method: :post,
    #   path:   "/v1/threads/#{thread_id}/messages",  # /v1 here
    #   body:   { role: "user", content: load_script_msg }
    # )
    openai_request(
      method: :post,
      path:   "/v1/threads/#{thread_id}/messages",
      body:   { role: "user", content: load_script_msg }
    )
    Rails.logger.info "[ParseScriptJob] → Sent full script to thread #{thread_id}."

    #
    # === 6) “Run” the assistant so it loads/stores the script ===
    #
    run_resp1 = openai_request(
      method: :post,
      path:   "/v1/threads/#{thread_id}/runs",  # /v1 here
      body:   { assistant_id: assistant_id }
    )
    # run_id  = run_resp["id"]         # the run’s ID (e.g. "run-abcd1234")
    # status  = run_resp["status"]     # the run’s initial status ("running"/"succeeded"/etc)
    run_id  = run_resp1["id"]
    status  = run_resp1["status"]

    while status != "succeeded" && status != "failed"
      sleep 0.5
      poll = openai_request(
        method: :get,
        path:   "/v1/threads/#{thread_id}/runs/#{run_id}"  # /v1 here
      )
      # status = poll.dig("run", "status")
      status = poll["status"]
    end
    if status == "failed"
      raise "[ParseScriptJob] Failed loading script: #{run_resp1.dig('run','error','message')}"
    end

    #
    # === 7) (Optional) Log the assistant’s confirmation message ===
    #
    messages = openai_request(
      method: :get,
      path:   "/v1/threads/#{thread_id}/messages"   # /v1 here
    ).dig("messages")
    loaded_reply = messages.reverse.find { |m| m["role"] == "assistant" }
    Rails.logger.info "[ParseScriptJob] → Script‐loaded reply: #{loaded_reply.inspect}"

    #
    # === 8) Ask to extract sluglines (POST /v1/threads/:thread_id/messages) ===
    #
    extract_payload = {
      role:    "user",
      content: <<~EXTRACT
        Please extract only the actual scene headings (sluglines) from the loaded script
        and return them as valid JSON. … (your full extraction instructions) …
      EXTRACT
    }
    openai_request(
      method: :post,
      path:   "/v1/threads/#{thread_id}/messages",   # /v1 here
      body:   extract_payload
    )
    # openai_request(
    #   method: :get,
    #   path:   "/v1/threads/#{thread_id}/messages"
    # )
    Rails.logger.info "[ParseScriptJob] → Sent extraction prompt to thread #{thread_id}."

    #
    # === 9) “Run” again to produce the JSON output ===
    #
    run_resp2 = openai_request(
      method: :post,
      path:   "/v1/threads/#{thread_id}/runs",  # /v1 here
      body:   { assistant_id: assistant_id }
    )
    # run_id2  = run_resp2.dig("run", "run_id")
    # status2  = run_resp2.dig("run", "status")
    run_id2  = run_resp2["id"]
    status2  = run_resp2["status"]
    while status2 != "succeeded" && status2 != "failed"
      sleep 0.5
      poll2 = openai_request(
        method: :get,
        path:   "/v1/threads/#{thread_id}/runs/#{run_id2}"  # /v1 here
      )
      # status2 = poll2.dig("run", "status")
      status2 = poll2["status"]
    end
    if status2 == "failed"
      raise "[ParseScriptJob] Failed extracting sluglines: #{run_resp2.dig('run','error','message')}"
    end

    #
    # === 10) Retrieve the assistant’s JSON reply ===
    #
    messages = openai_request(
      method: :get,
      path:   "/v1/threads/#{thread_id}/messages"   # /v1 here
    ).dig("messages")
    last_assistant_msg = messages.reverse.find { |m| m["role"] == "assistant" }
    sluglines_json     = last_assistant_msg["content"]
    Rails.logger.info "[ParseScriptJob] → Extracted sluglines JSON: #{sluglines_json.inspect}"

    #
    # === 11) Parse and store the JSON however you like ===
    #
    parsed = JSON.parse(sluglines_json)
    script.update!(sluglines: parsed["scenes"])

  rescue => e
    Rails.logger.error "[ParseScriptJob] ✗ #{e.class}: #{e.message}"
    raise
  end

  private

  # Helper: make authenticated HTTP requests to OpenAI endpoints (including Assistants V2)
  def openai_request(method:, path:, body: nil)
    uri  = URI.parse("#{OPENAI_BASE_URL}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request =
      case method
      when :get
        Net::HTTP::Get.new(uri.request_uri)
      when :post
        req = Net::HTTP::Post.new(uri.request_uri)
        req.body = JSON.generate(body) if body
        req
      when :delete
        Net::HTTP::Delete.new(uri.request_uri)
      when :patch
        req = Net::HTTP::Patch.new(uri.request_uri)
        req.body = JSON.generate(body) if body
        req
      else
        raise ArgumentError, "Unsupported method: #{method}"
      end

    request["Content-Type"]  = "application/json"
    request["Authorization"] = "Bearer #{ENV.fetch("OPENAI_API_KEY")}"
    request["OpenAI-Beta"]   = "assistants=v2"   # tell OpenAI "use the v2 Assistants API"

    response = http.request(request)
    begin
      parsed = JSON.parse(response.body)
    rescue JSON::ParserError
      raise "[OpenAI #{method.upcase} #{path}] Unexpected response: #{response.body}"
    end

    if response.code.to_i >= 400
      raise "[OpenAI API Error] #{parsed.dig('error','message') || response.body}"
    end

    parsed
  end
end




# # app/jobs/parse_script_job.rb
# require 'pdf/reader'
# require "ruby/openai"

# class ParseScriptJob < ApplicationJob
#   queue_as :default

#   def perform(production_id, script_id)
#     script = Script.find(script_id)

#     # 1) download the PDF from ActiveStorage
#     pdf_data = script.file.download

#     # 2) extract plain text
#     reader   = PDF::Reader.new(StringIO.new(pdf_data))
#     raw_text = reader.pages.map(&:text).join("\n\n")

#     prompt = <<~PROMPT


#       You are a script‐analysis assistant. You will receive the full text of a film script. Your job is to extract **only the actual scene headings (sluglines)** and return them as valid JSON with **two separate fields**:

#         1. `"index"`: a strictly sequential integer starting at 1 and incrementing by 1 for each extracted slugline, **regardless of the scene’s printed number**.
#         2. `"text"`: the exact scene heading as it appears in the script, including any alphanumeric suffix (e.g. “3A”, “34B”), without alteration.

#       **Output JSON format (no extra text, no commentary):**
#       ```json
#       {
#         "scenes": [
#           { "index": 1, "text": "1 INT. HOUSE – DAY" },
#           { "index": 2, "text": "2 EXT. GARDEN – DAY" },
#           { "index": 3, "text": "3A INT. GARDEN SHED – DAY" },
#           { "index": 4, "text": "3B INT. GARDEN SHED – NIGHT" },
#           { "index": 5, "text": "4 INT. HOUSE – DAY" }
#           // …etc.
#         ]
#       }
#       Strict Rules

#       Preserve the scene number exactly as it appears in the script.

#       If the script shows “3A INT. LOCATION TIME”, then "text" must begin with "3A".

#       If the script shows “34B EXT. LOCATION NIGHT”, then "text" must begin with "34B".

#       Do not strip away or renumber any lettered suffix.

#       Use "index" only to count sequentially, starting at 1.

#       The first slugline seen → "index": 1; second slugline → "index": 2; and so on.

#       Do not tie "index" to the numeric part of the scene heading.

#       If a slugline repeats with “CONT’D” or “CONTINUED,” ignore that repeat; it is not a new scene.

#       Only extract lines that are valid sluglines—lines that begin with either:

#       a scene number (e.g. “1 ”, “2 ”, “3A ”, “10B ”, etc.)

#       or “INT.”, “EXT.”, or “INT./EXT.” (in case the script omitted a printed number).

#       Each extracted slugline must match the pattern:


#       [scene number (digits, possibly followed by a letter)] [INT./EXT./INT./EXT.] [LOCATION] [TIME OF DAY]
#       Examples:

#       “3 INT. OFFICE – NIGHT”

#       “3A EXT. ALLEYWAY – DAY”

#       “10B INT./EXT. CAR – DAY”

#       Return only valid JSON—no extra quotes, no markdown fences, and no explanatory text.

#       If the script’s sluglines are uppercase or lowercase, preserve the original casing exactly.

#       Do not invent or hallucinate any sluglines. Only extract those that actually appear in the provided text.

#       Make sure you go all the way to the end of the script. Do not cut off at any point until you have reached the end of the script.

#       If a scene has a number and a letter, then the letter is part of the scene number. Include the letter in the scene number. This means that the scene number will be different that the index value for that object. Do not let this confuse you. If for instance the script shows “3A INT. LOCATION TIME”, then the scene number is 3A, not 3. Its index value is 3. If the next scene is “3B INT. LOCATION TIME”, then its scene number is 3B, not 3. Its index value is 4. If the next scene is “4 INT. LOCATION TIME”, then its scene number is 4. Its index value is 5. Index values are to be unique and sequential, always incrementing by 1. Do so until you have reached the end of the script.


#       =====
#       #{raw_text}
#     PROMPT

#     client   = OpenAI::Client.new(
#       access_token: ENV.fetch("OPENAI_API_KEY"),
#     request_timeout: 300)
#     # response = client.chat(
#     #   parameters: {
#     #     model: "gpt-4",
#     #     messages: [{ role: "user", content: prompt }]
#     #   }
#     # )
#     # response = client.chat(
#     #   parameters: {
#     #     model: "gpt-3.5-turbo-16k",            # ← smaller-cost 16 K-token window
#     #     messages: [{ role: "user", content: prompt }]
#     #   }
#     # )
#     response = client.chat(
#       parameters: {
#         model: "gpt-4.1-nano-2025-04-14",                    # ← full GPT-4 with 32 K window
#         messages: [{ role: "user", content: prompt }],
#         max_tokens: 32768,
#         temperature: 0
#       }
#     )
#     # response = client.chat(
#     #   parameters: {
#     #     model: "o4-mini-2025-04-16",  # ← o4-mini endpoint
#     #     messages: [{ role: "user", content: prompt }],
#     #     max_completion_tokens: 100_000,
#     #   }
#     # )

#     # Dump the entire JSON to your logs
#     Rails.logger.info "🤖 GPT-4 raw response for Script##{script_id}: #{response.to_json}"

#     # Then you can still pull out the part you care about
#     content = response.dig("choices",0,"message","content")
#     Rails.logger.info "🤖  Content: #{content.inspect}"



#     sluglines_json = response.dig("choices",0,"message","content")
#     Rails.logger.info "[ParseScriptJob] → #{sluglines_json}"
#   rescue => e
#     Rails.logger.error "[ParseScriptJob] ✗ #{e.class}: #{e.message}"
#     raise
#   end
# end
