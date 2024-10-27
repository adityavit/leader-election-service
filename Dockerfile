FROM golang:1.20 AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o leader-election-service

FROM alpine:3.17
RUN apk --no-cache add ca-certificates
WORKDIR /app
COPY --from=builder /app/leader-election-service .
CMD ["./leader-election-service"]
