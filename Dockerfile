FROM node:24-slim AS frontend
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY . .
RUN pnpm run build

FROM golang:1.26 AS backend
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
# Copy built assets from frontend stage to the correct location for embedding
COPY --from=frontend /app/pkg/server/public/assets ./pkg/server/public/assets
RUN CGO_ENABLED=0 GOOS=linux go build -o convos convos.go

RUN useradd -u 10001 convos

FROM scratch
LABEL maintainer="contact@convos.chat"


WORKDIR /app
COPY --from=backend /app/convos .
COPY --from=backend /etc/passwd /etc/passwd


# Set up environment variables
ENV CONVOS_HOME=/data
ENV CONVOS_LISTEN=http://0.0.0.0:3000
VOLUME ["/data"]

EXPOSE 3000

USER convos

ENTRYPOINT ["/app/convos"]
CMD ["daemon"]
