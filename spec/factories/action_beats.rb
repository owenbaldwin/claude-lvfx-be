FactoryBot.define do
  factory :action_beat do
    scene
    sequence
    script
    production
    number { Faker::Number.unique.between(from: 1, to: 100) }
    type { ['action', 'dialogue'].sample }
    text { Faker::Lorem.paragraph }
    description { Faker::Lorem.paragraph }
    
    trait :dialogue do
      type { 'dialogue' }
      dialogue { Faker::Movies::StarWars.character.upcase }
      text { Faker::Movies::StarWars.quote }
    end
    
    trait :action do
      type { 'action' }
      text { Faker::Lorem.paragraph }
    end
  end
end