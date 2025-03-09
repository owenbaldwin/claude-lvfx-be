FactoryBot.define do
  factory :production do
    title { Faker::Movie.title }
    description { Faker::Lorem.paragraph }
    start_date { Date.today }
    end_date { Date.today + 6.months }
    status { ['pre-production', 'production', 'post-production'].sample }
  end
end