require 'rails_helper'

RSpec.describe "Api::V1::Shots", type: :request do
  let(:user) { create(:user) }
  let(:production) { create(:production) }
  let(:script) { create(:script, production: production) }
  let(:sequence) { create(:sequence, script: script, production: production) }
  let(:scene) { create(:scene, sequence: sequence, script: script, production: production) }
  let(:action_beat) { create(:action_beat, scene: scene, sequence: sequence, script: script, production: production) }
  let(:auth_token) { generate_auth_token(user) }
  
  before do
    # Add user to production with appropriate role
    create(:production_user, user: user, production: production, role: 'admin')
  end
  
  describe "GET /api/v1/productions/:production_id/scripts/:script_id/sequences/:sequence_id/scenes/:scene_id/action_beats/:action_beat_id/shots" do
    it "returns a list of shots" do
      create_list(:shot, 3, action_beat: action_beat, scene: scene, sequence: sequence, script: script, production: production)
      
      get "/api/v1/productions/#{production.id}/scripts/#{script.id}/sequences/#{sequence.id}/scenes/#{scene.id}/action_beats/#{action_beat.id}/shots", 
          headers: { 'Authorization' => "Bearer #{auth_token}" }
      
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(3)
    end
  end
  
  describe "GET /api/v1/productions/:production_id/scripts/:script_id/sequences/:sequence_id/scenes/:scene_id/action_beats/:action_beat_id/shots/:id" do
    it "returns a specific shot" do
      shot = create(:shot, action_beat: action_beat, scene: scene, sequence: sequence, script: script, production: production)
      
      get "/api/v1/productions/#{production.id}/scripts/#{script.id}/sequences/#{sequence.id}/scenes/#{scene.id}/action_beats/#{action_beat.id}/shots/#{shot.id}", 
          headers: { 'Authorization' => "Bearer #{auth_token}" }
      
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['id']).to eq(shot.id)
    end
  end
  
  describe "POST /api/v1/productions/:production_id/scripts/:script_id/sequences/:sequence_id/scenes/:scene_id/action_beats/:action_beat_id/shots" do
    let(:valid_params) do
      {
        number: 1,
        description: "Close up of character's face",
        vfx: "no",
        duration: "00:00:10",
        camera_angle: "close up",
        camera_movement: "static"
      }
    end
    
    it "creates a new shot" do
      expect {
        post "/api/v1/productions/#{production.id}/scripts/#{script.id}/sequences/#{sequence.id}/scenes/#{scene.id}/action_beats/#{action_beat.id}/shots", 
             params: valid_params,
             headers: { 'Authorization' => "Bearer #{auth_token}" }
      }.to change(Shot, :count).by(1)
      
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['description']).to eq("Close up of character's face")
    end
    
    it "validates required fields" do
      post "/api/v1/productions/#{production.id}/scripts/#{script.id}/sequences/#{sequence.id}/scenes/#{scene.id}/action_beats/#{action_beat.id}/shots", 
           params: { number: 1 },
           headers: { 'Authorization' => "Bearer #{auth_token}" }
      
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors']).to include(/Description can't be blank/)
    end
  end
  
  describe "PUT /api/v1/productions/:production_id/scripts/:script_id/sequences/:sequence_id/scenes/:scene_id/action_beats/:action_beat_id/shots/:id" do
    let(:shot) { create(:shot, action_beat: action_beat, scene: scene, sequence: sequence, script: script, production: production) }
    
    it "updates an existing shot" do
      put "/api/v1/productions/#{production.id}/scripts/#{script.id}/sequences/#{sequence.id}/scenes/#{scene.id}/action_beats/#{action_beat.id}/shots/#{shot.id}", 
          params: { description: "Updated shot description", vfx: "yes" },
          headers: { 'Authorization' => "Bearer #{auth_token}" }
      
      expect(response).to have_http_status(:ok)
      shot.reload
      expect(shot.description).to eq("Updated shot description")
      expect(shot.vfx).to eq("yes")
    end
  end
  
  describe "DELETE /api/v1/productions/:production_id/scripts/:script_id/sequences/:sequence_id/scenes/:scene_id/action_beats/:action_beat_id/shots/:id" do
    let!(:shot) { create(:shot, action_beat: action_beat, scene: scene, sequence: sequence, script: script, production: production) }
    
    it "deletes a shot" do
      expect {
        delete "/api/v1/productions/#{production.id}/scripts/#{script.id}/sequences/#{sequence.id}/scenes/#{scene.id}/action_beats/#{action_beat.id}/shots/#{shot.id}", 
               headers: { 'Authorization' => "Bearer #{auth_token}" }
      }.to change(Shot, :count).by(-1)
      
      expect(response).to have_http_status(:no_content)
    end
  end
end