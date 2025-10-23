FROM ruby:3.2-alpine

# Install dependencies
RUN apk add --no-cache \
    build-base \
    git

# Set working directory
WORKDIR /app

# Copy Gemfile and install gems
COPY Gemfile ./
RUN bundle install

# Copy application code
COPY . .

# Make app.rb executable
RUN chmod +x app.rb

# Run the application
CMD ["ruby", "app.rb"]
