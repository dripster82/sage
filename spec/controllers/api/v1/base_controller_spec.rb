# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::BaseController, type: :controller do
  describe 'inheritance' do
    it 'inherits from ApplicationController' do
      expect(Api::V1::BaseController.superclass).to eq(ApplicationController)
    end
  end

  describe 'CSRF protection' do
    it 'skips CSRF protection for API requests' do
      # Check that the controller has the skip_before_action configured
      expect(Api::V1::BaseController.skip_forgery_protection).to include(:verify_authenticity_token)
    end
  end

  describe 'helper methods' do
    let(:controller) { Api::V1::BaseController.new }

    before do
      allow(controller).to receive(:render)
    end

    describe '#render_success' do
      it 'renders success response with data' do
        expect(controller).to receive(:render).with(
          json: { success: true, data: { test: 'data' } },
          status: :ok
        )
        controller.send(:render_success, { test: 'data' })
      end
    end

    describe '#render_error' do
      it 'renders error response with message' do
        expect(controller).to receive(:render).with(
          json: { success: false, error: 'Test error' },
          status: :bad_request
        )
        controller.send(:render_error, 'Test error')
      end
    end
  end
end
