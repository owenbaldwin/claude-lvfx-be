FactoryBot.define do
  factory :action_beat do
    association :scene
    association :sequence
    association :script
    association :production
    number { Faker::Number.unique.between(from: 1, to: 100) }
    beat_type { ['action', 'dialogue'].sample }
    text { Faker::Lorem.paragraph }
    description { Faker::Lorem.paragraph }
    
    trait :dialogue do
      beat_type { 'dialogue' }
      dialogue { Faker::Movies::StarWars.character.upcase }
      text { Faker::Movies::StarWars.quote }
    end
    
    trait :action do
      beat_type { 'action' }
      text { Faker::Lorem.paragraph }
    end
  end
end