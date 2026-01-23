# frozen_string_literal: true

module Api
  module V1
    module Users
      class CreditsController < Api::V1::BaseController
        include Authenticable

        before_action :authenticate_user!

        def show
          render_success({
            credits: @current_user.credits,
            email: @current_user.email,
            last_seen: @current_user.last_seen
          })
        end
      end
    end
  end
end

