FROM debian:bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libc6-dev make libpq-dev wget ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app
# Download mongoose single-header library
RUN wget -q https://raw.githubusercontent.com/cesanta/mongoose/7.14/mongoose.c && \
    wget -q https://raw.githubusercontent.com/cesanta/mongoose/7.14/mongoose.h

COPY main.c Makefile ./
RUN make

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends libpq5 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /app/server .
EXPOSE 8080
CMD ["./server"]
