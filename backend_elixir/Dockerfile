# ============================================================
# Stage 1 – Build
# ============================================================
FROM elixir:1.17-alpine AS builder

# Install build dependencies
RUN apk add --no-cache build-base git

WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

# Baked in at compile time — see endpoint.ex's `plug CORSPlug`.
ARG CORS_ORIGIN=http://localhost:3000
ENV CORS_ORIGIN=${CORS_ORIGIN}

# Copy dependency files first for layer caching
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy source and compile
COPY . .
RUN mix compile

# ============================================================
# Stage 2 – Runtime
# ============================================================
FROM elixir:1.17-alpine AS runtime

RUN apk add --no-cache libstdc++ openssl ncurses-libs

WORKDIR /app

# Install hex + rebar in runtime for mix phx.server
RUN mix local.hex --force && mix local.rebar --force

COPY --from=builder /app ./
COPY --from=builder /root/.mix /root/.mix

ENV MIX_ENV=prod \
    PHX_SERVER=true \
    PORT=3001

EXPOSE 3001

CMD ["mix", "phx.server"]
