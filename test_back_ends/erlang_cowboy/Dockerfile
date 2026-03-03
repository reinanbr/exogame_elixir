FROM erlang:27-alpine AS build
WORKDIR /app
RUN apk add --no-cache git
COPY rebar.config .
COPY src/ ./src/
RUN rebar3 release

FROM alpine:3.20
RUN apk add --no-cache libstdc++ ncurses-libs
WORKDIR /app
COPY --from=build /app/_build/default/rel/benchmark_erlang/ .
EXPOSE 8080
CMD ["bin/benchmark_erlang", "foreground"]
