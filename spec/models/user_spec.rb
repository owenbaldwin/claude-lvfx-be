require 'rails_helper'

RSpec.describe User, type: :model do
  # Association tests
  it { should have_many(:production_users) }
  it { should have_many(:productions).through(:production_users) }

  # Validation tests
  it { should validate_presence_of(:email) }
  it { should validate_uniqueness_of(:email) }
  it { should validate_presence_of(:password_digest) }

  # Create user test
  it "is valid with valid attributes" do
    user = User.new(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    expect(user).to be_valid
  end

  it "is not valid without a password" do
    user = User.new(email: "test@example.com")
    expect(user).to_not be_valid
  end
end