# Sub2API Docker Image

Sub2API is an AI API Gateway Platform for distributing and managing AI product subscription API quotas.

## Building Local Image

### Method 1: Direct docker build (Recommended)

```bash
# From project root directory
cd /path/to/sub2api

# Build image with default tag
docker build -t sub2api:local .

# Or with version info
docker build \
  --build-arg VERSION=1.0.0 \
  --build-arg COMMIT=$(git rev-parse --short HEAD) \
  -t sub2api:local .

# For China mainland (use Chinese mirror)
docker build \
  --build-arg GOPROXY=https://goproxy.cn,direct \
  --build-arg GOSUMDB=sum.golang.google.cn \
  -t sub2api:local .
```

### Method 2: Using docker-compose.override.yml

Create `deploy/docker-compose.override.yml`:

```yaml
services:
  sub2api:
    image: sub2api:local
    build:
      context: ..
      dockerfile: Dockerfile
```

Then run:

```bash
cd deploy
docker-compose build
docker-compose up -d
```

### Build Architecture

```
Dockerfile (Multi-stage build)
├── Stage 1: frontend-builder (Node 24 Alpine)
│   └── pnpm build → outputs to backend/internal/web/dist/
├── Stage 2: backend-builder (Go 1.25.5 Alpine)
│   └── go build -tags embed → embeds frontend assets
└── Stage 3: runtime (Alpine 3.20)
    └── Final ~30MB image
```

### Verify Build

```bash
# Check image size
docker images sub2api:local

# Test run (requires PostgreSQL and Redis)
docker run --rm sub2api:local --version
```

---

## Quick Start

```bash
docker run -d \
  --name sub2api \
  -p 8080:8080 \
  -e DATABASE_URL="postgres://user:pass@host:5432/sub2api" \
  -e REDIS_URL="redis://host:6379" \
  weishaw/sub2api:latest
```

## Docker Compose

```yaml
version: '3.8'

services:
  sub2api:
    image: weishaw/sub2api:latest
    ports:
      - "8080:8080"
    environment:
      - DATABASE_URL=postgres://postgres:postgres@db:5432/sub2api?sslmode=disable
      - REDIS_URL=redis://redis:6379
    depends_on:
      - db
      - redis

  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=sub2api
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

## Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `DATABASE_URL` | PostgreSQL connection string | Yes | - |
| `REDIS_URL` | Redis connection string | Yes | - |
| `PORT` | Server port | No | `8080` |
| `GIN_MODE` | Gin framework mode (`debug`/`release`) | No | `release` |

## Supported Architectures

- `linux/amd64`
- `linux/arm64`

## Tags

- `latest` - Latest stable release
- `x.y.z` - Specific version
- `x.y` - Latest patch of minor version
- `x` - Latest minor of major version

## Links

- [GitHub Repository](https://github.com/weishaw/sub2api)
- [Documentation](https://github.com/weishaw/sub2api#readme)
