FactoryBot.define do
  factory :sequence do
    association :script
    association :production
    number { Faker::Number.unique.between(from: 1, to: 100) }
    prefix { ["A", "B", "C", "D"].sample }
    name { Faker::Movie.title }
    description { Faker::Lorem.paragraph }
  end
end