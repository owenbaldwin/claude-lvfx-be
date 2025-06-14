source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.1.2"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
# gem "rails", "~> 7.0.4"
# gem "rails", "~> 6.1.7.3"
gem "rails", "~> 7.1.0"  # or whatever version was installed

# Use postgresql as the database for Active Record
gem "pg", "~> 1.4.5"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", "~> 5.0"

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem "jbuilder"

# Use Redis adapter to run Action Cable in production
# gem "redis", "~> 4.0"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ mingw mswin x64_mingw jruby ]

# Reduces boot times through caching; required in config/boot.rb
# gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin AJAX possible
gem "rack-cors"

# JWT for authentication
gem "jwt"

# For API serialization
gem "active_model_serializers"

# Multi-agent AI system - using existing ruby-openai gem
# gem "active_agent", github: "activeagents/active_agent"

# for PDF→text
gem 'pdf-reader'

# https://github.com/alexrudall/ruby-openai
# gem 'openai'
gem "ruby-openai", "~> 3.7"

gem 'active_storage_validations'

gem "sidekiq"

# gem "multipart-post"
gem "multipart-post", ">= 2.1"


group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri mingw x64_mingw ]

  # Testing framework
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "database_cleaner-active_record"
  gem "shoulda-matchers"
end

group :development do
  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
end
