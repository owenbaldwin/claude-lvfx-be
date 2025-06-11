class ProductionInitializer
  def initialize(production)
    @production     = production
    @user           = production.owner
    @complexity_map = {}
  end

  def call
    return unless @user # Only proceed if we have an owner

    create_complexities
    create_assumptions
  end

  private

  def create_complexities
    DEFAULT_COMPLEXITY_TEMPLATES.each do |attrs|
      record = @production.complexities.create!(
        key:         attrs[:key],
        level:       attrs[:level],
        description: attrs[:description],
        user:        @user
      )
      @complexity_map[attrs[:key]] = record
    end
  end

  def create_assumptions
    DEFAULT_VFX_ASSUMPTIONS.each do |attrs|
      complexity = @complexity_map.fetch(attrs[:complexity_key]) do
        raise "Missing complexity template for key #{attrs[:complexity_key].inspect}"
      end

      @production.assumptions.create!(
        name:          attrs[:name],
        description:   attrs[:description],
        category:      attrs[:category],
        complexity_id: complexity.id
      )
    end
  end
end
