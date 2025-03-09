require 'rails_helper'

RSpec.describe 'Authentication', type: :request do
  describe 'POST /api/v1/auth/login' do
    let!(:user) { User.create(email: 'test@example.com', password: 'password123', password_confirmation: 'password123') }
    
    context 'When credentials are valid' do
      before do
        post '/api/v1/auth/login', params: { email: 'test@example.com', password: 'password123' }
      end

      it 'returns a token' do
        expect(JSON.parse(response.body)['token']).to be_present
      end

      it 'returns a 200 status code' do
        expect(response).to have_http_status(200)
      end
    end

    context 'When credentials are invalid' do
      before do
        post '/api/v1/auth/login', params: { email: 'test@example.com', password: 'wrong_password' }
      end

      it 'returns an error message' do
        expect(JSON.parse(response.body)['error']).to eq('unauthorized')
      end

      it 'returns a 401 status code' do
        expect(response).to have_http_status(401)
      end
    end
  end
end