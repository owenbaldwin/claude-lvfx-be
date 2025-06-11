require 'json'
require 'ruby/openai'

class ShotAssumptionsGeneratorService
  attr_reader :production, :shots, :existing_assumptions, :context

  def initialize(production:, shots:, context: nil)
    @production = production
    @shots = shots
    @context = context
    @existing_assumptions = load_existing_assumptions
  end

  def call
    prompt = build_prompt
    response = call_openai_api(prompt)
    parse_response(response)
  end

  private

  def load_existing_assumptions
    production.assumptions.includes(:complexity).map do |assumption|
      {
        id: assumption.id,
        name: assumption.name,
        description: assumption.description,
        category: assumption.category,
        complexity: {
          level: assumption.complexity.level,
          description: assumption.complexity.description
        }
      }
    end
  end

  def build_prompt
    shots_data = shots.map do |shot|
      {
        id: shot.id,
        description: shot.description,
        action_beat_description: shot.action_beat.text
      }
    end

    <<~PROMPT
      You are an AI assistant helping to generate assumptions for film/TV production shots.

      Context: #{context.present? ? context : 'No additional context provided'}

      SHOTS TO ANALYZE:
      #{shots_data.to_json}

      EXISTING ASSUMPTIONS IN THIS PRODUCTION:
      #{existing_assumptions.to_json}

      INSTRUCTIONS:
      Analyze each shot and return a JSON object mapping each shot ID to an array of assumption objects.

      For each shot, determine what assumptions are needed based on:
      1. The shot description
      2. The action beat context
      3. Technical requirements
      4. Visual effects needs
      5. Equipment requirements

      For each assumption, you can either:
      - Reference an existing assumption by ID if it's applicable
      - Create a new assumption with name, description, category, complexity_level, and complexity_description

      Categories should be one of: technical, creative, logistical, equipment, vfx, lighting, sound
      Complexity levels should be: low, medium, high, extreme

      Return ONLY valid JSON in this format:
      {
        "shot_id": [
          {
            "type": "existing",
            "assumption_id": 123
          },
          {
            "type": "new",
            "name": "Steadicam Equipment",
            "description": "Requires stabilized camera movement for smooth tracking",
            "category": "equipment",
            "complexity_level": "medium",
            "complexity_description": "Moderate equipment setup and operator skill required"
          }
        ]
      }
    PROMPT
  end

  def call_openai_api(prompt)
    client = OpenAI::Client.new(
      access_token: ENV.fetch("OPENAI_API_KEY"),
      request_timeout: 300
    )

    retries_left = 2

    begin
      response = client.chat(
        parameters: {
          model: "gpt-4.1-nano-2025-04-14",
          messages: [{ role: "user", content: prompt }],
          max_tokens: 32768,
          temperature: 0.1
        }
      )

      content = response.dig("choices", 0, "message", "content")

      if content.blank?
        raise StandardError, "Empty response from OpenAI"
      end

      content

    rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Net::ReadTimeout => e
      if retries_left > 0
        retries_left -= 1
        Rails.logger.warn "[ShotAssumptionsGeneratorService] Network error, retrying (#{retries_left} left): #{e.class}"
        sleep(2 + rand(3))
        retry
      else
        raise StandardError, "Network failed after retries: #{e.class}: #{e.message}"
      end
    end
  end

  def parse_response(raw_response)
    begin
      JSON.parse(raw_response)
    rescue JSON::ParserError => e
      Rails.logger.error "[ShotAssumptionsGeneratorService] JSON parse failed: #{e.message}"
      Rails.logger.error "Raw response: #{raw_response.inspect}"

      # Try to fix common JSON issues
      fixed_response = attempt_json_fix(raw_response)

      begin
        JSON.parse(fixed_response)
      rescue JSON::ParserError => e2
        raise StandardError, "Failed to parse OpenAI response as JSON: #{e2.message}"
      end
    end
  end

  def attempt_json_fix(raw_response)
    # Remove markdown code blocks if present
    cleaned = raw_response.gsub(/```json\s*/, '').gsub(/```\s*$/, '')

    # Try to ensure proper closing braces
    open_braces = cleaned.count('{')
    close_braces = cleaned.count('}')

    if open_braces > close_braces
      cleaned += '}' * (open_braces - close_braces)
    end

    open_brackets = cleaned.count('[')
    close_brackets = cleaned.count(']')

    if open_brackets > close_brackets
      cleaned += ']' * (open_brackets - close_brackets)
    end

    cleaned
  end
end
