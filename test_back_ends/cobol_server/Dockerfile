FROM debian:bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc gnucobol4 libc6-dev make libpq-dev wget ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN wget -q https://raw.githubusercontent.com/cesanta/mongoose/7.14/mongoose.c && \
    wget -q https://raw.githubusercontent.com/cesanta/mongoose/7.14/mongoose.h

COPY logic.cob glue.c ./

# Compile COBOL to object file, then link with C glue
RUN cobc -c -static logic.cob -o logic.o && \
    gcc -O2 -c glue.c -I/usr/include/gnucobol -o glue.o && \
    gcc -O2 -c mongoose.c -o mongoose.o && \
    gcc -O2 -o server logic.o glue.o mongoose.o -lpq -lpthread -lcob

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 libcob4 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /app/server .
EXPOSE 8080
CMD ["./server"]
