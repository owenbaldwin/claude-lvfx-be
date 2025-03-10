require 'rails_helper'

RSpec.describe ActionBeat, type: :model do
  let(:production) { create(:production) }
  let(:script) { create(:script, production: production) }
  let(:sequence) { create(:sequence, script: script, production: production) }
  let(:scene) { create(:scene, sequence: sequence, script: script, production: production) }
  
  describe "associations" do
    it { should belong_to(:scene) }
    it { should belong_to(:sequence) }
    it { should belong_to(:script) }
    it { should belong_to(:production) }
    it { should have_many(:shots).dependent(:destroy) }
  end
  
  describe "validations" do
    subject { build(:action_beat, scene: scene, sequence: sequence, script: script, production: production) }
    
    it { should validate_presence_of(:number) }
    it { should validate_numericality_of(:number).only_integer }
    it { should validate_presence_of(:text) }
    it { should validate_inclusion_of(:beat_type).in_array(['dialogue', 'action']) }
    
    it "validates uniqueness of number within a scene" do
      create(:action_beat, scene: scene, sequence: sequence, script: script, production: production, number: 1)
      duplicate = build(:action_beat, scene: scene, sequence: sequence, script: script, production: production, number: 1)
      
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:number]).to include("must be unique within a scene")
    end
  end
  
  describe "creation" do
    it "creates a valid action beat" do
      action_beat = build(:action_beat, 
        scene: scene, 
        sequence: sequence, 
        script: script, 
        production: production,
        number: 1,
        beat_type: "action",
        text: "John walks into the room slowly",
        description: "Show tension in his movements"
      )
      
      expect(action_beat).to be_valid
      expect(action_beat.save).to be true
    end
    
    it "creates a valid dialogue beat" do
      dialogue_beat = build(:action_beat, 
        scene: scene, 
        sequence: sequence, 
        script: script, 
        production: production,
        number: 2,
        beat_type: "dialogue",
        text: "I don't know what to do anymore.",
        dialogue: "JOHN"
      )
      
      expect(dialogue_beat).to be_valid
      expect(dialogue_beat.save).to be true
    end
  end
end