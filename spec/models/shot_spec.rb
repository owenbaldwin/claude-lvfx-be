require 'rails_helper'

RSpec.describe Shot, type: :model do
  let(:production) { create(:production) }
  let(:script) { create(:script, production: production) }
  let(:sequence) { create(:sequence, script: script, production: production) }
  let(:scene) { create(:scene, sequence: sequence, script: script, production: production) }
  let(:action_beat) { create(:action_beat, scene: scene, sequence: sequence, script: script, production: production) }
  
  describe "associations" do
    it { should belong_to(:action_beat) }
    it { should belong_to(:scene) }
    it { should belong_to(:sequence) }
    it { should belong_to(:script) }
    it { should belong_to(:production) }
  end
  
  describe "validations" do
    subject { build(:shot, action_beat: action_beat, scene: scene, sequence: sequence, script: script, production: production) }
    
    it { should validate_presence_of(:number) }
    it { should validate_numericality_of(:number).only_integer }
    it { should validate_presence_of(:description) }
    it { should validate_inclusion_of(:vfx).in_array(['yes', 'no']) }
    it { should validate_presence_of(:camera_angle) }
    it { should validate_presence_of(:camera_movement) }
    
    it "validates uniqueness of number within an action beat" do
      create(:shot, action_beat: action_beat, scene: scene, sequence: sequence, script: script, production: production, number: 1)
      duplicate = build(:shot, action_beat: action_beat, scene: scene, sequence: sequence, script: script, production: production, number: 1)
      
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:number]).to include("must be unique within an action beat")
    end
  end
  
  describe "creation" do
    it "creates a valid shot" do
      shot = build(:shot, 
        action_beat: action_beat, 
        scene: scene, 
        sequence: sequence, 
        script: script, 
        production: production,
        number: 1,
        description: "Close up of John's face as he enters",
        vfx: "no",
        duration: "00:00:08",
        camera_angle: "close up",
        camera_movement: "static"
      )
      
      expect(shot).to be_valid
      expect(shot.save).to be true
    end
    
    it "creates a valid VFX shot" do
      vfx_shot = build(:shot, 
        action_beat: action_beat, 
        scene: scene, 
        sequence: sequence, 
        script: script, 
        production: production,
        number: 2,
        description: "Wide shot of castle with digital extension",
        vfx: "yes",
        duration: "00:00:12",
        camera_angle: "wide",
        camera_movement: "slow pan"
      )
      
      expect(vfx_shot).to be_valid
      expect(vfx_shot.save).to be true
    end
  end
end