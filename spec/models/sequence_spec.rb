require 'rails_helper'

RSpec.describe Sequence, type: :model do
  let(:production) { create(:production) }
  let(:script) { create(:script, production: production) }
  
  describe "associations" do
    it { should belong_to(:script) }
    it { should belong_to(:production) }
    it { should have_many(:scenes).dependent(:destroy) }
    it { should have_many(:action_beats).through(:scenes) }
    it { should have_many(:shots).through(:action_beats) }
  end
  
  describe "validations" do
    subject { build(:sequence, script: script, production: production) }
    
    it { should validate_presence_of(:number) }
    it { should validate_numericality_of(:number).only_integer }
    it { should validate_presence_of(:name) }
    
    it "validates uniqueness of number within a script" do
      create(:sequence, script: script, production: production, number: 1)
      duplicate = build(:sequence, script: script, production: production, number: 1)
      
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:number]).to include("must be unique within a script")
    end
  end
  
  describe "creation" do
    it "creates a valid sequence" do
      sequence = build(:sequence, 
        script: script, 
        production: production,
        number: 1,
        prefix: "A",
        name: "Beginning",
        description: "The start of the story"
      )
      
      expect(sequence).to be_valid
      expect(sequence.save).to be true
    end
  end
end