FROM elixir:1.17-otp-27-alpine AS build

RUN apk add --no-cache git

WORKDIR /app
ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs ./
RUN mix deps.get --only prod && mix deps.compile

COPY config ./config
COPY lib ./lib
RUN mix compile && mix release

FROM alpine:3.20
RUN apk add --no-cache libstdc++ libgcc ncurses-libs
WORKDIR /app
COPY --from=build /app/_build/prod/rel/benchmark_phoenix ./
ENV PHX_HOST=0.0.0.0
EXPOSE 8080
CMD ["bin/benchmark_phoenix", "start"]
