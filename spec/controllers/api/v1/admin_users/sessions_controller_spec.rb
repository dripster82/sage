# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::AdminUsers::SessionsController, type: :controller do
  let(:admin_user) { create(:admin_user, email: 'test@example.com', password: 'password123') }

  describe 'POST #create' do
    context 'with valid credentials' do
      let(:valid_params) do
        {
          email: admin_user.email,
          password: 'password123'
        }
      end

      it 'returns JWT tokens' do
        post :create, params: valid_params, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        expect(json_response['auth_token']).to be_present
        expect(json_response['refresh_token']).to be_present
        
        # Verify the tokens are valid
        decoded_auth_token = AdminUsers::TokenService.decode_token(json_response['auth_token'])
        decoded_refresh_token = AdminUsers::TokenService.decode_token(json_response['refresh_token'])
        
        expect(decoded_auth_token['admin_user_id']).to eq(admin_user.id)
        expect(decoded_refresh_token['admin_user_id']).to eq(admin_user.id)
      end
    end

    context 'with invalid email' do
      let(:invalid_params) do
        {
          email: 'nonexistent@example.com',
          password: 'password123'
        }
      end

      it 'returns unauthorized error' do
        post :create, params: invalid_params, format: :json
        
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Invalid email or password')
      end
    end

    context 'with invalid password' do
      let(:invalid_params) do
        {
          email: admin_user.email,
          password: 'wrong_password'
        }
      end

      it 'returns unauthorized error' do
        post :create, params: invalid_params, format: :json
        
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Invalid email or password')
      end
    end

    context 'when an exception occurs' do
      before do
        allow(AdminUser).to receive(:find_for_database_authentication).and_raise(StandardError.new('Database error'))
      end

      it 'returns internal server error' do
        post :create, params: { email: 'test@example.com', password: 'password' }, format: :json
        
        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Something went wrong')
      end
    end
  end
end
