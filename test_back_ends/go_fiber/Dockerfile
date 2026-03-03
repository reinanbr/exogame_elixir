FROM golang:1.22-alpine AS build
WORKDIR /app
COPY go.mod go.sum* ./
RUN go mod download 2>/dev/null || true
COPY . .
RUN go mod tidy && CGO_ENABLED=0 go build -ldflags="-s -w" -o server .

FROM alpine:3.19
COPY --from=build /app/server /server
EXPOSE 8080
CMD ["/server"]
