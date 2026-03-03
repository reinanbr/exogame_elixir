FROM ruby:3.3-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libpq-dev && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY Gemfile ./
RUN bundle install --jobs 4

COPY config.ru ./

EXPOSE 8080
CMD ["falcon", "serve", "--bind", "http://0.0.0.0:8080", "--count", "4"]
