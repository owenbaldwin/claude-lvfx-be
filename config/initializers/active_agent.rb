# Multi-Agent Script Parser Configuration
# Configure the custom multi-agent system for script parsing

# Ensure OpenAI API key is available
if ENV['OPENAI_API_KEY'].blank?
  Rails.logger.warn "[MultiAgentParser] ⚠️ OPENAI_API_KEY not set - multi-agent parsing unavailable"
else
  Rails.logger.info "[MultiAgentParser] 🤖 Multi-agent script parser initialized"
  Rails.logger.info "[MultiAgentParser] Using OpenAI API for agent communication"
end

# Configuration constants for the multi-agent system
module MultiAgentConfig
  DEFAULT_MODEL = "gpt-4.1-nano-2025-04-14"
  DEFAULT_TEMPERATURE = 0.1  # Lower temperature for more consistent parsing
  DEFAULT_MAX_TOKENS = 32768   # Reasonable token limit for script parsing
  MAX_RETRIES = 3            # Maximum retries for failed operations
end
