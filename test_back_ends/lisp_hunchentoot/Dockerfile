FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    sbcl curl ca-certificates libpq5 build-essential libpq-dev && \
    rm -rf /var/lib/apt/lists/*

# Install Quicklisp
RUN curl -o /tmp/ql.lisp https://beta.quicklisp.org/quicklisp.lisp && \
    sbcl --non-interactive --load /tmp/ql.lisp \
         --eval '(quicklisp-quickstart:install)' \
         --eval '(ql:add-to-init-file)' && \
    rm /tmp/ql.lisp

# Pre-download deps
RUN sbcl --non-interactive \
    --eval '(ql:quickload (list :hunchentoot :hunchensocket :postmodern :cl-json :bordeaux-threads) :silent t)'

WORKDIR /app
COPY server.lisp .

EXPOSE 8080
CMD ["sbcl", "--non-interactive", "--load", "server.lisp"]
