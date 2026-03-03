FROM debian:bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc gfortran libc6-dev make libpq-dev wget ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN wget -q https://raw.githubusercontent.com/cesanta/mongoose/7.14/mongoose.c && \
    wget -q https://raw.githubusercontent.com/cesanta/mongoose/7.14/mongoose.h

COPY logic.f90 glue.c ./

# Compile Fortran module, then link with C glue + mongoose
RUN gfortran -O2 -c logic.f90 -o logic.o && \
    gcc -O2 -c glue.c -o glue.o && \
    gcc -O2 -c mongoose.c -o mongoose.o && \
    gfortran -O2 -o server logic.o glue.o mongoose.o -lpq -lpthread -lgfortran

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 libgfortran5 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /app/server .
EXPOSE 8080
CMD ["./server"]
