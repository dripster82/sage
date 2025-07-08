# Use official Ruby image
FROM ruby:3.4.4

# Install dependencies
RUN apt-get update -qq && apt-get install -y \
  build-essential \
  libpq-dev \
  nodejs \
  yarn \
  npm \
  && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Configure bundler
ENV LANG=C.UTF-8 \
  BUNDLE_JOBS=4 \
  BUNDLE_RETRY=3


# Install gems
RUN gem install bundler

# Install yarn globally
RUN npm install -g yarn

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install Ruby gems
RUN bundle install

# Copy the rest of the application code
COPY . .

# Create the database
# RUN bundle exec rails db:create
# # Run migrations
# RUN bundle exec rails db:migrate
# # Seed the database
# RUN bundle exec rails db:seed
# Install JavaScript dependencies
RUN bundle exec rails g active_admin:assets
# Precompile assets
RUN bundle exec rake assets:precompile

# Expose port 3000
EXPOSE 3000

CMD ['tail', '-f', '/dev/null']