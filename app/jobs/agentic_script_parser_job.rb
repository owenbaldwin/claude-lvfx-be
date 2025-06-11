class AgenticScriptParserJob < ApplicationJob
  queue_as :default

  def perform(script_id, script_parse_id = nil)
    Rails.logger.info "[AgenticScriptParserJob] 🚀 Starting agentic script parsing for Script##{script_id}"

    # Find the script_parse record if provided
    script_parse = nil
    if script_parse_id
      script_parse = ScriptParse.find_by(id: script_parse_id)
      if script_parse
        script_parse.update!(status: 'processing')
        Rails.logger.info "[AgenticScriptParserJob] 📊 Updated ScriptParse##{script_parse_id} status to 'processing'"
      end
    end

    # Initialize the script parser agent
    parser_agent = ScriptParserAgent.new

    # Attempt to parse the script
    success = parser_agent.parse_script(script_id)

    if success
      Rails.logger.info "[AgenticScriptParserJob] ✅ Agentic parsing succeeded for Script##{script_id}"

      # Update script_parse status to completed
      if script_parse
        script_parse.update!(
          status: 'completed',
          results_json: {
            message: 'Agentic script parsing completed successfully',
            agent_used: 'multi-agent system',
            timestamp: Time.current.iso8601
          }
        )
        Rails.logger.info "[AgenticScriptParserJob] ✅ Updated ScriptParse##{script_parse_id} status to 'completed'"
      end
    else
      Rails.logger.error "[AgenticScriptParserJob] ❌ Agentic parsing failed for Script##{script_id}"

      # Update script_parse status to failed
      if script_parse
        script_parse.update!(
          status: 'failed',
          error: 'Multi-agent script parsing failed. Check logs for details.'
        )
        Rails.logger.error "[AgenticScriptParserJob] ❌ Updated ScriptParse##{script_parse_id} status to 'failed'"
      end
    end

  rescue => e
    Rails.logger.error "[AgenticScriptParserJob] ❌ Job failed with exception: #{e.class}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    # Update script_parse status to failed with error details
    if script_parse
      script_parse.update!(
        status: 'failed',
        error: "Job failed: #{e.message}"
      )
      Rails.logger.error "[AgenticScriptParserJob] ❌ Updated ScriptParse##{script_parse_id} status to 'failed' due to exception"
    end

    raise # Re-raise to ensure job is marked as failed in the queue
  end
end
