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
      You are a script-analysis assistant. Extract only the sluglines (INT/EXT, location, time)
      from the following script text. Return a JSON array of strings.

      =====
      #{raw_text}
    PROMPT

    client   = OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY"))
    response = client.chat(
      parameters: {
        model: "gpt-4",
        messages: [{ role: "user", content: prompt }]
      }
    )

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
