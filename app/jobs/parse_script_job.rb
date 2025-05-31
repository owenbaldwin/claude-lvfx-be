# app/jobs/parse_script_job.rb

require "pdf/reader"
require "net/http"
require "uri"
require "json"
require "net/http/post/multipart"  # ← make sure `gem "multipart-post"` is in your Gemfile

class ParseScriptJob < ApplicationJob
  queue_as :default

  OPENAI_BASE_URL = "https://api.openai.com"

  def perform(production_id, script_id)
    script = Script.find(script_id)

    # ── (1) Ensure the script has a PDF attached ──
    unless script.file.attached?
      raise "No PDF attached to Script##{script_id}"
    end

    # ── (2) Download the raw PDF bytes ──
    pdf_bytes = script.file.download

    # ── (3) (Optional) Extract raw_text via PDF::Reader if you also want to send plain text ──
    reader   = PDF::Reader.new(StringIO.new(pdf_bytes))
    raw_text = reader.pages.map(&:text).join("\n")

    #
    # === A) UPLOAD THE PDF TO OPENAI FILES (v1/files?purpose=assistants) ===
    #
    file_id = upload_pdf_to_openai(pdf_bytes)
    Rails.logger.info "[ParseScriptJob] → Uploaded PDF, got file_id=#{file_id}"

    #
    # === B) CREATE A VECTOR STORE FOR FILE_SEARCH (v1/vector_stores) ===
    #
    vector_store_resp = openai_request(
      method: :post,
      path:   "/v1/vector_stores",
      body:   { name: "script-vector-store-#{script_id}", file_ids: [file_id] }
    )
    vector_store_id = vector_store_resp["id"]
    Rails.logger.info "[ParseScriptJob] → Created vector store #{vector_store_id}, status=#{vector_store_resp["status"]}"

    # Poll until vector store ingestion is complete
    loop do
      vs = openai_request(
        method: :get,
        path:   "/v1/vector_stores/#{vector_store_id}"
      )
      status = vs["status"]
      Rails.logger.info "[ParseScriptJob] → Polling vector store #{vector_store_id}, status=#{status}"
      case status
      when "completed"
        break
      when "failed"
        raise "[ParseScriptJob] Vector store ingestion failed for #{vector_store_id}"
      else
        sleep 1
      end
    end
    Rails.logger.info "[ParseScriptJob] → Vector store #{vector_store_id} ingestion completed"

    #
    # === C) CREATE THE ASSISTANT (v1/assistants) AND ATTACH THE VECTOR STORE AS A TOOL_RESOURCE ===
    #
    assistant_payload = {
      name:        "script-slugline-extractor-#{script_id}",
      description: "Loads a full script PDF and returns JSON of scene sluglines",
      model:       "gpt-4o-mini",
      instructions: <<~SYSMSG.chomp,
        You are a script‐analysis assistant. You have been given a single PDF
        containing a film script. Your job is to extract only the scene headings
        (sluglines) and return them as valid JSON with two fields:

          1. "index": a sequential integer starting at 1 (ignore any printed scene number).
          2. "text": the exact slugline text (e.g. "1 INT. HOUSE – DAY", "3A EXT. GARDEN – DAY").

        Output JSON only, no extra commentary:

        {
          "scenes": [
            { "index": 1, "text": "1 INT. HOUSE – DAY" },
            { "index": 2, "text": "2 EXT. GARDEN – DAY" },
            { "index": 3, "text": "3A INT. OFFICE – NIGHT" }
          ]
        }

        Strict rules: Do not alter the text, preserve any alphanumeric suffix, go to the end.
      SYSMSG
      tools: [
        { type: "file_search" }
      ],
      tool_resources: {
        file_search: {
          vector_store_ids: [vector_store_id]
        }
      },
      response_format: { type: "json_object" }
    }

    assistant_resp = openai_request(
      method: :post,
      path:   "/v1/assistants",
      body:   assistant_payload
    )
    assistant_id = assistant_resp["id"]
    Rails.logger.info "[ParseScriptJob] → Created assistant #{assistant_id}"

    #
    # === D) SPAWN A THREAD UNDER THAT ASSISTANT ===
    #
    thread_resp = openai_request(
      method: :post,
      path:   "/v1/assistants/#{assistant_id}/threads",
      body:   nil
    )
    thread_id = thread_resp["id"]
    Rails.logger.info "[ParseScriptJob] → Created thread #{thread_id}"

    #
    # === E) (Optional) SEND RAW‐TEXT AS A MESSAGE ===
    #
    load_script_msg = <<~LOADMSG
      LOAD_SCRIPT:
      #{raw_text}
    LOADMSG

    openai_request(
      method: :post,
      path:   "/v1/assistants/#{assistant_id}/threads/#{thread_id}/messages",
      body:   { role: "user", content: load_script_msg }
    )
    Rails.logger.info "[ParseScriptJob] → Sent raw text to thread #{thread_id}."

    #
    # === F) RUN ONCE SO THE ASSISTANT “INGESTS” THE PDF (and raw_text if you sent it) ===
    #
    run_resp1 = openai_request(
      method: :post,
      path:   "/v1/assistants/#{assistant_id}/threads/#{thread_id}/runs",
      body:   { assistant_id: assistant_id }
    )
    run_id = run_resp1["id"]
    status = run_resp1["status"]
    Rails.logger.info "[ParseScriptJob] → Started initial run #{run_id}, status=#{status}"

    until (status == "succeeded") || (status == "failed")
      sleep 0.5
      poll = openai_request(
        method: :get,
        path:   "/v1/threads/#{thread_id}/runs/#{run_id}"
      )
      status = poll["status"]
      Rails.logger.info "[ParseScriptJob] → Polling run #{run_id}, status=#{status}"
    end
    if status == "failed"
      raise "[ParseScriptJob] Failed loading script into assistant run: #{run_resp1.dig('run','error','message')}"
    end

    #
    # === G) SEND THE EXTRACTION PROMPT AS A NEW MESSAGE ===
    #
    extract_payload = {
      role:    "user",
      content: <<~EXTRACT.chomp
        Please extract only the scene headings (sluglines) from the script
        already loaded via the PDF, and return them as valid JSON as per instructions.
      EXTRACT
    }
    openai_request(
      method: :post,
      path:   "/v1/assistants/#{assistant_id}/threads/#{thread_id}/messages",
      body:   extract_payload
    )
    Rails.logger.info "[ParseScriptJob] → Sent extraction prompt to thread #{thread_id}."

    #
    # === H) RUN AGAIN TO PRODUCE THE JSON OUTPUT ===
    #
    run_resp2 = openai_request(
      method: :post,
      path:   "/v1/assistants/#{assistant_id}/threads/#{thread_id}/runs",
      body:   { assistant_id: assistant_id }
    )
    run_id2 = run_resp2["id"]
    status2 = run_resp2["status"]
    Rails.logger.info "[ParseScriptJob] → Started extraction run #{run_id2}, status=#{status2}"

    until (status2 == "succeeded") || (status2 == "failed")
      sleep 0.5
      poll2 = openai_request(
        method: :get,
        path:   "/v1/threads/#{thread_id}/runs/#{run_id2}"
      )
      status2 = poll2["status"]
      Rails.logger.info "[ParseScriptJob] → Polling run #{run_id2}, status=#{status2}"
    end
    if status2 == "failed"
      raise "[ParseScriptJob] Failed extracting sluglines: #{run_resp2.dig('run','error','message')}"
    end

    #
    # === I) RETRIEVE THE ASSISTANT’S JSON REPLY ===
    #
    messages = openai_request(
      method: :get,
      path:   "/v1/assistants/#{assistant_id}/threads/#{thread_id}/messages"
    ).dig("messages")
    last_assistant_msg = messages.reverse.find { |m| m["role"] == "assistant" }
    sluglines_json     = last_assistant_msg["content"]
    Rails.logger.info "[ParseScriptJob] → Extracted sluglines JSON: #{sluglines_json.inspect}"

    #
    # === J) PARSE & STORE JSON IN YOUR DB ===
    #
    parsed = JSON.parse(sluglines_json)
    script.update!(sluglines: parsed["scenes"])

  rescue => e
    Rails.logger.error "[ParseScriptJob] ✗ #{e.class}: #{e.message}"
    raise
  end

  private

  # --------------------------------------------
  # Helper: UPLOAD A PDF TO OPENAI (v1/files) to get a file_id
  # --------------------------------------------
  def upload_pdf_to_openai(pdf_bytes)
    uri  = URI.parse("#{OPENAI_BASE_URL}/v1/files")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    multipart_req = Net::HTTP::Post::Multipart.new(
      uri.request_uri,
      "file"    => UploadIO.new(StringIO.new(pdf_bytes), "application/pdf", "script.pdf"),
      "purpose" => "assistants"
    )
    multipart_req["Authorization"] = "Bearer #{ENV.fetch("OPENAI_API_KEY")}"
    # No OpenAI-Beta header here—just a normal v1/files call.

    resp = http.request(multipart_req)
    begin
      parsed = JSON.parse(resp.body)
    rescue JSON::ParserError
      raise "[OpenAI UPLOAD] Unexpected response: #{resp.body}"
    end

    if resp.code.to_i >= 400
      raise "[OpenAI API Error] #{parsed.dig('error','message') || resp.body}"
    end

    parsed["id"]
  end

  # --------------------------------------------
  # Helper: GENERIC OPENAI REQUEST (v1-Assistants, v1/files, v1/vector_stores)
  # --------------------------------------------
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
    request["OpenAI-Beta"]   = "assistants=v2"   # required when calling any /v1/assistants route

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
# require "pdf/reader"
# require "net/http"
# require "uri"
# require "json"

# class ParseScriptJob < ApplicationJob
#   queue_as :default

#   OPENAI_BASE_URL = "https://api.openai.com"

#   def perform(production_id, script_id)
#     script = Script.find(script_id)

#      # ── Extract raw_text from the attached PDF before anything else ──
#     unless script.file.attached?
#       raise "No PDF attached to Script##{script_id}"
#     end

#     # (1) Download PDF bytes from ActiveStorage
#     pdf_bytes = script.file.download

#     # (2) Build a PDF::Reader over those bytes
#     reader = PDF::Reader.new(StringIO.new(pdf_bytes))

#     # (3) Concatenate all pages’ plain text into one String
#     raw_text = reader.pages.map(&:text).join("\n")


#     system_prompt = <<~SYSMSG.chomp
#       You are a script‐analysis assistant. You will receive the full text of a film script.
#       Your job is to extract only the actual scene headings (sluglines) and return them as valid JSON
#       with two separate fields:

#         1. "index": a strictly sequential integer starting at 1 and incrementing by 1
#            for each extracted slugline, regardless of the scene’s printed number.
#         2. "text": the exact scene heading as it appears in the script, including any alphanumeric suffix
#            (e.g. "3A", "34B"), without alteration.

#       Output JSON format (no extra text, no commentary):
#       {
#         "scenes": [
#           { "index": 1, "text": "1 INT. HOUSE – DAY" },
#           { "index": 2, "text": "2 EXT. GARDEN – DAY" },
#           // …etc.
#         ]
#       }

#       Strict Rules: (…all your rules here…)
#       Make sure you go all the way to the end of the script. …
#     SYSMSG

#     #
# # === 3) Create the assistant under /v1/assistants with "assistants=v2" header ===
# #
# # assistant_payload = {
# #   name:         "script-slugline-extractor-#{script_id}",
# #   description:  "Loads a full script and returns JSON of scene sluglines",
# #   model:        "gpt-4o-mini",
# #   instructions: system_prompt
# # }


# # assistant_resp = openai_request(
# #   method: :post,
# #   path:   "/v1/assistants",        # keep /v1 here
# #   body:   assistant_payload
# # )

# # assistant_id = assistant_resp.dig("id")

# assistant_payload = {
#   name:         "script-slugline-extractor-#{script_id}",
#   description:  "Loads a full script and returns JSON of scene sluglines",
#   model:        "gpt-4o-mini",
#   instructions: system_prompt,
#   tools:        ["file_search"]                 # ← enable file_search
# }

# assistant_resp = openai_request(
#   method: :post,
#   path:   "/v1/assistants",
#   body:   assistant_payload
# )
# assistant_id = assistant_resp["id"]


# Rails.logger.info "[ParseScriptJob] → Created assistant #{assistant_id}"

#     #
#     # === 4) Create a thread under that assistant (POST /v1/threads) ===
#     #
#     # thread_resp = openai_request(
#     #   method: :post,
#     #   path:   "/v1/threads",         # keep /v1 here
#     #   body:   nil   # or omit `body:` altogether
#     # )

#     # # thread_id = thread_resp.dig("thread", "thread_id")
#     # # thread_id = thread_resp.dig("thread", "id")
#     # thread_id = thread_resp.dig("id")
#     # Rails.logger.info "[ParseScriptJob] → Created thread #{thread_id}"
#     # Corrected “create thread”:
#     # thread_resp = openai_request(
#     #   method: :post,
#     #   path:   "/v1/threads",
#     #   body:   nil
#     # )
#     thread_resp = openai_request(
#       method: :post,
#       path:   "/v1/assistants/#{assistant_id}/threads",
#       body:   nil
#     )
#     thread_id = thread_resp.dig("id")   # ← not dig("thread","id")
#     Rails.logger.info "[ParseScriptJob] → Created thread #{thread_id}"


#     #
#     # === 5) Send the entire raw script as a “user” message ===
#     #
#     load_script_msg = <<~LOADMSG
#       LOAD_SCRIPT:
#       #{raw_text}
#     LOADMSG

#     # openai_request(
#     #   method: :post,
#     #   path:   "/v1/threads/#{thread_id}/messages",  # /v1 here
#     #   body:   { role: "user", content: load_script_msg }
#     # )
#     # openai_request(
#     #   method: :post,
#     #   path:   "/v1/threads/#{thread_id}/messages",
#     #   body:   { role: "user", content: load_script_msg }
#     # )
#     openai_request(
#       method: :post,
#       path:   "/v1/assistants/#{assistant_id}/threads/#{thread_id}/messages",
#       body:   { role: "user", content: load_script_msg }
#     )
#     Rails.logger.info "[ParseScriptJob] → Sent full script to thread #{thread_id}."

#     #
#     # === 6) “Run” the assistant so it loads/stores the script ===
#     #
#     # run_resp1 = openai_request(
#     #   method: :post,
#     #   path:   "/v1/threads/#{thread_id}/runs",  # /v1 here
#     #   body:   { assistant_id: assistant_id }
#     # )
#     run_resp1 = openai_request(
#       method: :post,
#       path:   "/v1/assistants/#{assistant_id}/threads/#{thread_id}/runs",
#       body:   { assistant_id: assistant_id }
#     )

#     run_id  = run_resp1["id"]
#     status  = run_resp1["status"]
#     Rails.logger.info "[ParseScriptJob] → Started first run #{run_id}, status=#{status}"

#     while status != "succeeded" && status != "failed"
#       sleep 0.5
#       poll = openai_request(
#         method: :get,
#         path:   "/v1/threads/#{thread_id}/runs/#{run_id}"  # /v1 here
#       )
#       # status = poll.dig("run", "status")
#       status = poll["status"]
#       Rails.logger.info "[ParseScriptJob] → Polling run #{run_id}, status=#{status}"
#     end
#     if status == "failed"
#       raise "[ParseScriptJob] Failed loading script: #{run_resp1.dig('run','error','message')}"
#     end

#     #
#     # === 7) (Optional) Log the assistant’s confirmation message ===
#     #
#     # messages = openai_request(
#     #   method: :get,
#     #   path:   "/v1/threads/#{thread_id}/messages"   # /v1 here
#     # ).dig("messages")
#     messages = openai_request(
#       method: :get,
#       path:   "/v1/assistants/#{assistant_id}/threads/#{thread_id}/messages"
#     ).dig("messages")

#     loaded_reply = messages.reverse.find { |m| m["role"] == "assistant" }
#     Rails.logger.info "[ParseScriptJob] → Script‐loaded reply: #{loaded_reply.inspect}"

#     #
#     # === 8) Ask to extract sluglines (POST /v1/threads/:thread_id/messages) ===
#     #
#     extract_payload = {
#       role:    "user",
#       content: <<~EXTRACT
#         Please extract only the actual scene headings (sluglines) from the loaded script
#         and return them as valid JSON. … (your full extraction instructions) …
#       EXTRACT
#     }
#     # openai_request(
#     #   method: :post,
#     #   path:   "/v1/threads/#{thread_id}/messages",   # /v1 here
#     #   body:   extract_payload
#     # )
#     openai_request(
#       method: :post,
#       path:   "/v1/assistants/#{assistant_id}/threads/#{thread_id}/messages",
#       body:   extract_payload
#     )

#     Rails.logger.info "[ParseScriptJob] → Sent extraction prompt to thread #{thread_id}."

#     #
#     # === 9) “Run” again to produce the JSON output ===
#     #
#     # run_resp2 = openai_request(
#     #   method: :post,
#     #   path:   "/v1/threads/#{thread_id}/runs",  # /v1 here
#     #   body:   { assistant_id: assistant_id }
#     # )
#     run_resp2 = openai_request(
#       method: :post,
#       path:   "/v1/assistants/#{assistant_id}/threads/#{thread_id}/runs",
#       body:   { assistant_id: assistant_id }
#     )
#     # run_id2  = run_resp2.dig("run", "run_id")
#     # status2  = run_resp2.dig("run", "status")
#     run_id2  = run_resp2["id"]
#     status2  = run_resp2["status"]
#     while status2 != "succeeded" && status2 != "failed"
#       sleep 0.5
#       poll2 = openai_request(
#         method: :get,
#         path:   "/v1/threads/#{thread_id}/runs/#{run_id2}"  # /v1 here
#       )
#       # status2 = poll2.dig("run", "status")
#       status2 = poll2["status"]
#     end
#     if status2 == "failed"
#       raise "[ParseScriptJob] Failed extracting sluglines: #{run_resp2.dig('run','error','message')}"
#     end

#     #
#     # === 10) Retrieve the assistant’s JSON reply ===
#     #
#     # messages = openai_request(
#     #   method: :get,
#     #   path:   "/v1/threads/#{thread_id}/messages"   # /v1 here
#     # ).dig("messages")
#     messages = openai_request(
#       method: :get,
#       path:   "/v1/assistants/#{assistant_id}/threads/#{thread_id}/messages"
#     ).dig("messages")

#     last_assistant_msg = messages.reverse.find { |m| m["role"] == "assistant" }
#     sluglines_json     = last_assistant_msg["content"]
#     Rails.logger.info "[ParseScriptJob] → Extracted sluglines JSON: #{sluglines_json.inspect}"

#     #
#     # === 11) Parse and store the JSON however you like ===
#     #
#     parsed = JSON.parse(sluglines_json)
#     script.update!(sluglines: parsed["scenes"])

#   rescue => e
#     Rails.logger.error "[ParseScriptJob] ✗ #{e.class}: #{e.message}"
#     raise
#   end

#   private

#   # Helper: make authenticated HTTP requests to OpenAI endpoints (including Assistants V2)
#   def openai_request(method:, path:, body: nil)
#     uri  = URI.parse("#{OPENAI_BASE_URL}#{path}")
#     http = Net::HTTP.new(uri.host, uri.port)
#     http.use_ssl = true

#     request =
#       case method
#       when :get
#         Net::HTTP::Get.new(uri.request_uri)
#       when :post
#         req = Net::HTTP::Post.new(uri.request_uri)
#         req.body = JSON.generate(body) if body
#         req
#       when :delete
#         Net::HTTP::Delete.new(uri.request_uri)
#       when :patch
#         req = Net::HTTP::Patch.new(uri.request_uri)
#         req.body = JSON.generate(body) if body
#         req
#       else
#         raise ArgumentError, "Unsupported method: #{method}"
#       end

#     request["Content-Type"]  = "application/json"
#     request["Authorization"] = "Bearer #{ENV.fetch("OPENAI_API_KEY")}"
#     request["OpenAI-Beta"]   = "assistants=v2"   # tell OpenAI "use the v2 Assistants API"

#     response = http.request(request)
#     begin
#       parsed = JSON.parse(response.body)
#     rescue JSON::ParserError
#       raise "[OpenAI #{method.upcase} #{path}] Unexpected response: #{response.body}"
#     end

#     if response.code.to_i >= 400
#       raise "[OpenAI API Error] #{parsed.dig('error','message') || response.body}"
#     end

#     parsed
#   end
# end
