class GenerateShotAssumptionsJob < ApplicationJob
  queue_as :default

  def perform(production_id:, shot_ids:, context: nil)
    Rails.logger.info "[GenerateShotAssumptionsJob] Starting job for production #{production_id} with shot_ids: #{shot_ids}"

    begin
      # Load production and shots with necessary associations
      production = Production.find(production_id)
      shots = production.shots.includes(:action_beat, :assumptions).where(id: shot_ids)

      if shots.count != shot_ids.count
        raise StandardError, "Not all shots found for production #{production_id}"
      end

      Rails.logger.info "[GenerateShotAssumptionsJob] Loaded #{shots.count} shots"

      # Call the service to generate assumptions
      service = ShotAssumptionsGeneratorService.new(
        production: production,
        shots: shots,
        context: context
      )

      response_data = service.call
      Rails.logger.info "[GenerateShotAssumptionsJob] Received response from OpenAI service"

      # Process the response for each shot
      processed_shots = []
      response_data.each do |shot_id_str, assumptions_array|
        shot_id = shot_id_str.to_i
        shot = shots.find { |s| s.id == shot_id }

        unless shot
          Rails.logger.warn "[GenerateShotAssumptionsJob] Could not find shot with id #{shot_id}"
          next
        end

        unless assumptions_array.is_a?(Array)
          Rails.logger.warn "[GenerateShotAssumptionsJob] Assumptions for shot #{shot_id} is not an array: #{assumptions_array.inspect}"
          next
        end

        process_shot_assumptions(shot, assumptions_array, production)
        processed_shots << shot_id
      end

      Rails.logger.info "[GenerateShotAssumptionsJob] Successfully processed #{processed_shots.count} shots"

      # Broadcast update to frontend (you can implement this based on your WebSocket setup)
      broadcast_assumptions_update(production_id, processed_shots)

    rescue => e
      Rails.logger.error "[GenerateShotAssumptionsJob] Job failed: #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    end
  end

  private

  def process_shot_assumptions(shot, assumptions_array, production)
    assumptions_array.each do |assumption_data|
      unless assumption_data.is_a?(Hash)
        Rails.logger.warn "[GenerateShotAssumptionsJob] Invalid assumption data for shot #{shot.id}: #{assumption_data.inspect}"
        next
      end

      begin
        case assumption_data["type"]
        when "existing"
          link_existing_assumption(shot, assumption_data["assumption_id"])
        when "new"
          create_and_link_new_assumption(shot, assumption_data, production)
        else
          Rails.logger.warn "[GenerateShotAssumptionsJob] Unknown assumption type: #{assumption_data['type']}"
        end
      rescue => e
        Rails.logger.error "[GenerateShotAssumptionsJob] Failed to process assumption for shot #{shot.id}: #{e.class}: #{e.message}"
        next
      end
    end
  end

  def link_existing_assumption(shot, assumption_id)
    assumption = shot.production.assumptions.find_by(id: assumption_id)

    unless assumption
      Rails.logger.warn "[GenerateShotAssumptionsJob] Existing assumption #{assumption_id} not found"
      return
    end

    # Check if association already exists
    unless shot.shot_assumptions.exists?(assumption: assumption)
      ShotAssumption.create!(shot: shot, assumption: assumption)
      Rails.logger.debug "[GenerateShotAssumptionsJob] Linked existing assumption #{assumption_id} to shot #{shot.id}"
    end
  end

  def create_and_link_new_assumption(shot, assumption_data, production)
    # Validate required fields
    required_fields = %w[name description category complexity_level complexity_description]
    missing_fields = required_fields.select { |field| assumption_data[field].blank? }

    if missing_fields.any?
      Rails.logger.warn "[GenerateShotAssumptionsJob] Missing required fields for new assumption: #{missing_fields.join(', ')}"
      return
    end

    ActiveRecord::Base.transaction do
      # Create or find complexity
      complexity = find_or_create_complexity(
        production: production,
        level: assumption_data["complexity_level"],
        description: assumption_data["complexity_description"]
      )

      # Create assumption
      assumption = Assumption.create!(
        production: production,
        complexity: complexity,
        name: assumption_data["name"],
        description: assumption_data["description"],
        category: assumption_data["category"]
      )

      # Link to shot
      ShotAssumption.create!(shot: shot, assumption: assumption)

      Rails.logger.debug "[GenerateShotAssumptionsJob] Created and linked new assumption '#{assumption.name}' to shot #{shot.id}"
    end
  end

  def find_or_create_complexity(production:, level:, description:)
    # Try to find existing complexity with same level and description
    existing = production.complexities.find_by(
      level: level,
      description: description
    )

    return existing if existing

    # Create new complexity with a unique key
    key = generate_complexity_key(production, level)

    Complexity.create!(
      production: production,
      user: User.first, # You might want to pass the user from the job parameters
      level: level,
      description: description,
      key: key
    )
  end

  def generate_complexity_key(production, level)
    base_key = "#{level}_auto"
    counter = 1

    while production.complexities.exists?(key: "#{base_key}_#{counter}")
      counter += 1
    end

    "#{base_key}_#{counter}"
  end

  def broadcast_assumptions_update(production_id, shot_ids)
    # This is a placeholder for WebSocket broadcasting
    # You can implement this based on your WebSocket setup (ActionCable, etc.)
    Rails.logger.info "[GenerateShotAssumptionsJob] Broadcasting update for production #{production_id}, shots: #{shot_ids}"

    # Example using Rails cache (you can replace with your preferred notification method)
    Rails.cache.write(
      "assumptions_updated_#{production_id}",
      {
        shot_ids: shot_ids,
        updated_at: Time.current
      },
      expires_in: 1.hour
    )
  end
end
