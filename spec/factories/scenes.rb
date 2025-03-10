FactoryBot.define do
  factory :scene do
    sequence
    script
    production
    number { Faker::Number.unique.between(from: 1, to: 100) }
    int_ext { ['interior', 'exterior'].sample }
    location { Faker::Movies::HarryPotter.location }
    day_night { ['day', 'night', 'dawn', 'dusk'].sample }
    length { "#{Faker::Number.between(from: 1, to: 5)} minutes" }
    description { Faker::Lorem.paragraph }
  end
end