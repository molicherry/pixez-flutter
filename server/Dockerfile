FROM rust:1.88-slim-bookworm AS builder

RUN apt-get update && apt-get install -y --no-install-recommends pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY Cargo.toml Cargo.lock* ./
COPY src/ src/
COPY migrations/ migrations/

RUN cargo build --release && cp target/release/pixez-sync-server /usr/local/bin/

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/bin/pixez-sync-server /usr/local/bin/pixez-sync-server
COPY static/ /app/static/

WORKDIR /app
EXPOSE 8080
CMD ["pixez-sync-server"]
