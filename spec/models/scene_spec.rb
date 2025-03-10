require 'rails_helper'

RSpec.describe Scene, type: :model do
  let(:production) { create(:production) }
  let(:script) { create(:script, production: production) }
  let(:sequence) { create(:sequence, script: script, production: production) }
  
  describe "associations" do
    it { should belong_to(:sequence) }
    it { should belong_to(:script) }
    it { should belong_to(:production) }
    it { should have_many(:action_beats).dependent(:destroy) }
    it { should have_many(:shots).through(:action_beats) }
  end
  
  describe "validations" do
    subject { build(:scene, sequence: sequence, script: script, production: production) }
    
    it { should validate_presence_of(:number) }
    it { should validate_numericality_of(:number).only_integer }
    it { should validate_presence_of(:location) }
    it { should validate_inclusion_of(:int_ext).in_array(['interior', 'exterior']) }
    it { should validate_presence_of(:day_night) }
    
    it "validates uniqueness of number within a sequence" do
      create(:scene, sequence: sequence, script: script, production: production, number: 1)
      duplicate = build(:scene, sequence: sequence, script: script, production: production, number: 1)
      
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:number]).to include("must be unique within a sequence")
    end
  end
  
  describe "creation" do
    it "creates a valid scene" do
      scene = build(:scene, 
        sequence: sequence, 
        script: script, 
        production: production,
        number: 1,
        location: "Castle",
        int_ext: "interior",
        day_night: "night",
        length: "2 minutes",
        description: "The hero enters the castle"
      )
      
      expect(scene).to be_valid
      expect(scene.save).to be true
    end
  end
end