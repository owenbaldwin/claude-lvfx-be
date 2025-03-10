require 'rails_helper'

RSpec.describe "Api::V1::Sequences", type: :request do
  let(:user) { create(:user) }
  let(:production) { create(:production) }
  let(:script) { create(:script, production: production) }
  let(:auth_token) { generate_auth_token(user) }
  
  before do
    # Add user to production with appropriate role
    create(:production_user, user: user, production: production, role: 'admin')
  end
  
  describe "GET /api/v1/productions/:production_id/scripts/:script_id/sequences" do
    it "returns a list of sequences" do
      create_list(:sequence, 3, script: script, production: production)
      
      get "/api/v1/productions/#{production.id}/scripts/#{script.id}/sequences", 
          headers: { 'Authorization' => "Bearer #{auth_token}" }
      
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(3)
    end
  end
  
  describe "GET /api/v1/productions/:production_id/scripts/:script_id/sequences/:id" do
    it "returns a specific sequence" do
      sequence = create(:sequence, script: script, production: production)
      
      get "/api/v1/productions/#{production.id}/scripts/#{script.id}/sequences/#{sequence.id}", 
          headers: { 'Authorization' => "Bearer #{auth_token}" }
      
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['id']).to eq(sequence.id)
    end
  end
  
  describe "POST /api/v1/productions/:production_id/scripts/:script_id/sequences" do
    let(:valid_params) do
      {
        number: 5,
        prefix: "A",
        name: "Opening Sequence",
        description: "The beginning of the movie"
      }
    end
    
    it "creates a new sequence" do
      expect {
        post "/api/v1/productions/#{production.id}/scripts/#{script.id}/sequences", 
             params: valid_params,
             headers: { 'Authorization' => "Bearer #{auth_token}" }
      }.to change(Sequence, :count).by(1)
      
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['name']).to eq("Opening Sequence")
    end
    
    it "validates required fields" do
      post "/api/v1/productions/#{production.id}/scripts/#{script.id}/sequences", 
           params: { description: "Missing required fields" },
           headers: { 'Authorization' => "Bearer #{auth_token}" }
      
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors']).to include(/Number can't be blank/)
    end
  end
  
  describe "PUT /api/v1/productions/:production_id/scripts/:script_id/sequences/:id" do
    let(:sequence) { create(:sequence, script: script, production: production) }
    
    it "updates an existing sequence" do
      put "/api/v1/productions/#{production.id}/scripts/#{script.id}/sequences/#{sequence.id}", 
          params: { name: "Updated Sequence Name" },
          headers: { 'Authorization' => "Bearer #{auth_token}" }
      
      expect(response).to have_http_status(:ok)
      expect(sequence.reload.name).to eq("Updated Sequence Name")
    end
  end
  
  describe "DELETE /api/v1/productions/:production_id/scripts/:script_id/sequences/:id" do
    let!(:sequence) { create(:sequence, script: script, production: production) }
    
    it "deletes a sequence" do
      expect {
        delete "/api/v1/productions/#{production.id}/scripts/#{script.id}/sequences/#{sequence.id}", 
               headers: { 'Authorization' => "Bearer #{auth_token}" }
      }.to change(Sequence, :count).by(-1)
      
      expect(response).to have_http_status(:no_content)
    end
  end
end