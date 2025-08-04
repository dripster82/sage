# frozen_string_literal: true

# Shared examples for ActiveRecord models
RSpec.shared_examples 'an ActiveRecord model' do
  it 'is valid with valid attributes' do
    expect(subject).to be_valid
  end

  it 'has a created_at timestamp' do
    subject.save!
    expect(subject.created_at).to be_present
  end

  it 'has an updated_at timestamp' do
    subject.save!
    expect(subject.updated_at).to be_present
  end
end

# Shared examples for models with validations
RSpec.shared_examples 'validates presence of' do |attribute|
  it "validates presence of #{attribute}" do
    subject.send("#{attribute}=", nil)
    expect(subject).not_to be_valid
    expect(subject.errors[attribute]).to include("can't be blank")
  end
end

RSpec.shared_examples 'validates uniqueness of' do |attribute|
  it "validates uniqueness of #{attribute}" do
    existing_record = create(described_class.name.underscore.to_sym)
    subject.send("#{attribute}=", existing_record.send(attribute))
    expect(subject).not_to be_valid
    expect(subject.errors[attribute]).to include('has already been taken')
  end
end

# Shared examples for services
RSpec.shared_examples 'a service object' do
  it 'responds to call or process method' do
    service_instance = defined?(service) ? service : subject
    expect(service_instance).to respond_to(:call).or respond_to(:process)
  end
end

# Shared examples for controllers
RSpec.shared_examples 'requires authentication' do
  it 'redirects to login when not authenticated' do
    subject
    expect(response).to redirect_to(new_admin_user_session_path)
  end
end

RSpec.shared_examples 'returns successful response' do
  it 'returns a successful response' do
    subject
    expect(response).to be_successful
  end
end

# Shared examples for JSON responses
RSpec.shared_examples 'returns JSON response' do |status|
  it "returns #{status} status with JSON content type" do
    subject
    expect(response).to have_http_status(status)
    expect(response.content_type).to include('application/json')
  end
end

# Shared examples for error handling
RSpec.shared_examples 'handles errors gracefully' do |error_class|
  it "handles #{error_class} gracefully" do
    allow(subject).to receive(:call).and_raise(error_class)
    expect { subject.call }.not_to raise_error
  end
end
