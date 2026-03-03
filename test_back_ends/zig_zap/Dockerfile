FROM ghcr.io/ziglang/zig:0.13.0 AS build
WORKDIR /app
COPY build.zig build.zig.zon src/ ./src/
RUN zig build -Doptimize=ReleaseFast

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends libpq5 ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /app/zig-out/bin/benchmark_zig .
EXPOSE 8080
CMD ["./benchmark_zig"]
