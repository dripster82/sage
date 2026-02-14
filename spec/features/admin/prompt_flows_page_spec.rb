# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Prompt Flows Admin Page', type: :feature do
  let(:admin_user) { create(:admin_user) }

  before do
    sign_in admin_user, scope: :admin_user
  end

  it 'loads the prompt flows index' do
    create(:prompt_flow, name: 'Flow One')

    visit '/admin/prompt_flows'

    expect(page).to have_content('Prompt Flows')
    expect(page).to have_content('Flow One')
  end

  it 'shows the flow canvas panel on show page' do
    flow = create(:prompt_flow, name: 'Flow Canvas')

    visit "/admin/prompt_flows/#{flow.id}"

    expect(page).to have_css('#prompt-flow-canvas')
    expect(page).to have_content('Canvas will render here')
  end
end
