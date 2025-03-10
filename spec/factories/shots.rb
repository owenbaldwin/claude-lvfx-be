FactoryBot.define do
  factory :shot do
    action_beat
    scene
    sequence
    script
    production
    number { Faker::Number.unique.between(from: 1, to: 100) }
    description { Faker::Lorem.paragraph }
    vfx { ['yes', 'no'].sample }
    duration { "00:00:#{Faker::Number.between(from: 5, to: 30)}" }
    camera_angle { ['wide', 'medium', 'close up', 'extreme close up', 'over the shoulder'].sample }
    camera_movement { ['static', 'pan', 'tilt', 'dolly', 'track', 'crane', 'handheld', 'steadicam'].sample }
    
    trait :vfx do
      vfx { 'yes' }
      description { "#{Faker::Lorem.paragraph} with #{Faker::Lorem.word} VFX enhancement" }
    end
    
    trait :no_vfx do
      vfx { 'no' }
    end
  end
end