# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Sub2API is an AI API gateway platform for distributing and managing API quotas from AI product subscriptions (like Claude Code $200/month). It acts as a proxy layer between users and upstream AI services (Claude, Gemini, OpenAI, Antigravity), handling authentication, billing, load balancing, and request forwarding.

**Key Features:**
- Multi-account management (OAuth, API Key)
- API key distribution for users
- Token-level billing and usage tracking
- Smart account scheduling with sticky sessions
- Per-user and per-account concurrency control
- Rate limiting with configurable cooldowns

**Tech Stack:**
- **Backend:** Go 1.25.5, Gin (HTTP), Ent (ORM), Wire (DI - archived), PostgreSQL, Redis
- **Frontend:** Vue 3.4+, Vite 5+, TypeScript, TailwindCSS, Pinia (state)

> **Note:** Google Wire was archived on Aug 25, 2025. The existing code works but no new features will be added.

## Fork 專案說明

本專案是 [Wei-Shaw/sub2api](https://github.com/Wei-Shaw/sub2api) 的 fork，維護繁體中文翻譯。

### 上游同步與繁體中文化

> **重要**：執行同步前，請先閱讀 [i18n-traditional-chinese.md](docs/i18n-traditional-chinese.md) 中的「手動校正詞彙對照表」，確保套用所有校正規則。

```bash
# 1. 同步上游
git fetch upstream
git merge upstream/main

# 2. 批次繁體中文化（推薦）
./scripts/convert-to-traditional-chinese.sh

# 3. 驗證
cd frontend && pnpm run typecheck

# 4. 提交
git add -A && git commit -m "chore(i18n): update Traditional Chinese translations"
```

**腳本選項：**
```bash
./scripts/convert-to-traditional-chinese.sh -n   # Dry run（預覽）
./scripts/convert-to-traditional-chinese.sh -v   # 詳細輸出
```

**必讀文件：**
- [scripts/convert-config.sh](scripts/convert-config.sh) - **腳本配置檔**（OpenCC 同步、手動校正、排除規則）
- [i18n-traditional-chinese.md](docs/i18n-traditional-chinese.md) - 完整中文化流程
- [fork-sync-workflow.md](docs/fork-sync-workflow.md) - Fork 同步策略與衝突處理

## Common Commands

### Backend (Go)

```bash
# Working directory: backend/

# Build the server binary (without embedded frontend)
make build
# Output: bin/server

# Build with embedded frontend (for production)
go build -tags embed -o sub2api ./cmd/server

# Run all tests + linting
make test

# Run tests by category
make test-unit          # Unit tests only
make test-integration   # Integration tests (uses testcontainers)
make test-e2e           # End-to-end tests

# Run linter only
golangci-lint run ./...

# Run a single test
go test -tags=unit ./internal/service -run TestAccountService_Create

# Generate Ent code + Wire DI after schema changes
go generate ./ent
go generate ./cmd/server

# Run the server (development mode)
go run ./cmd/server
```

### Frontend (Vue/TypeScript)

```bash
# Working directory: frontend/

# Install dependencies
pnpm install

# Start dev server (with hot reload)
pnpm run dev

# Build for production (outputs to ../backend/internal/web/dist/)
pnpm run build

# Lint and auto-fix
pnpm run lint

# Type check without building
pnpm run typecheck

# Lint check only (no auto-fix)
pnpm run lint:check
```

### Full Build Process (Frontend + Backend)

```bash
# 1. Build frontend
cd frontend
pnpm install
pnpm run build  # Outputs to backend/internal/web/dist/

# 2. Build backend with embedded frontend
cd ../backend
go build -tags embed -o sub2api ./cmd/server

# 3. Run the binary
./sub2api
```

## Architecture

### Backend Architecture

**Layered Structure:**
```
cmd/server/            # Application entry point
├── main.go            # Server initialization
├── wire.go            # Wire DI providers
└── wire_gen.go        # Generated DI code

internal/
├── config/            # Configuration management (Viper)
├── handler/           # HTTP handlers (Gin)
│   ├── admin/         # Admin dashboard handlers
│   ├── dto/           # Data transfer objects
│   └── gateway_handler.go   # Main gateway proxy logic
├── service/           # Business logic layer
│   ├── gateway_service.go           # API proxying
│   ├── concurrency_service.go       # Slot-based concurrency
│   ├── billing_service.go           # Token billing
│   ├── billing_cache_service.go     # Async cache writes
│   ├── ratelimit_service.go         # Rate limit handling
│   ├── token_refresher.go           # OAuth token refresh
│   └── ...
├── repository/        # Data access layer (Ent)
├── server/            # Server setup and middleware
├── integration/       # Upstream API clients
├── pkg/               # Shared utilities
│   └── errors/        # Custom error types
└── web/               # Embedded frontend assets

ent/                   # Ent ORM (schema-first)
├── schema/            # Entity schemas (source of truth)
│   ├── account.go
│   ├── user.go
│   ├── group.go
│   └── ...
└── generate.go        # Code generation trigger

migrations/            # Database migration SQL files
```

### Key Backend Patterns

#### 1. Gateway Flow
```
Client Request → Gin Handler → Gateway Service → Account Scheduler
                                               → Upstream Client → AI API
                                               ← Billing Service ← Response
```

#### 2. Account Scheduling & Concurrency
- **Slot-based concurrency:** Redis-backed ordered sets track active request slots per account
- **Account state management:** Multiple state flags (RateLimited, Overloaded, TempUnschedulable)
- **Sticky sessions:** Session hash-based account routing with TTL-based Redis caching
- **Timing wheel:** Uses go-zero's TimingWheel for delayed tasks (account re-enablement)

#### 3. Billing & Usage
- **Dynamic + Fallback pricing:** Primary from PricingService (LiteLLM format), fallback hardcoded
- **Token-based cost:** Breaks down by input, output, cache creation, cache read
- **Async cache writes:** 10 workers with 1000-item buffer, non-blocking enqueue
- **Circuit breaker:** Protects billing checks during outages

#### 4. Error Handling Pattern
```go
// Always wrap errors with context
err := fmt.Errorf("operation: %w", err)

// Use ApplicationError for service errors
type ApplicationError struct {
    Code     int               // HTTP status code
    Reason   string            // Machine-readable classification
    Message  string            // Human-readable message
    Metadata map[string]any    // Additional context
    Cause    error             // Wrapped error
}
```

#### 5. Rate Limit Handling
- **401/402/403:** Disable account (auth/payment failures)
- **429:** Rate limit with Retry-After header parsing
- **529:** Overload handling with exponential backoff
- **5xx:** Log but don't disable (transient failures)

#### 6. Wire DI Pattern
```go
// Provider functions follow NewXxxService pattern
func ProvidePricingService(cfg *config.Config, ...) (*PricingService, error) {
    svc := NewPricingService(...)
    if err := svc.Initialize(); err != nil {
        println("[Service] Warning: ...", err.Error())  // Non-fatal
    }
    return svc, nil
}
```

#### 7. Repository Pattern
- Interface-based dependencies for all services
- Domain-specific methods (not generic repositories)
- Batch operations support (GetByIDs)
- Bulk update with nil pointers for "don't change"

### Frontend Architecture

```
src/
├── views/             # Page components (routed)
│   ├── admin/         # Admin dashboard pages
│   ├── Login.vue
│   └── Dashboard.vue
├── components/        # Reusable UI components
│   ├── common/        # Generic (DataTable, Modal, Toast)
│   ├── layout/        # AppLayout, AuthLayout
│   └── admin/         # Admin-specific components
├── stores/            # Pinia state management
│   ├── auth.ts        # Authentication state
│   ├── app.ts         # Global UI state, toasts
│   └── subscriptions.ts
├── api/               # API client (axios)
│   ├── client.ts      # Base HTTP client with interceptors
│   ├── auth.ts
│   └── admin/         # Admin API modules
├── router/            # Vue Router with guards
├── i18n/              # Internationalization (en/zh)
├── composables/       # Reusable logic hooks
│   ├── useForm.ts
│   ├── useTableLoader.ts
│   └── useClipboard.ts
└── utils/             # Helper functions
```

### Key Frontend Patterns

#### 1. API Client Structure
- Axios with interceptors for auth and error handling
- Request interceptor: Bearer token, locale, timezone headers
- Response interceptor: Unwraps `{ code, message, data }` format
- 401 handling: Token cleanup and redirect to login

#### 2. State Management (Pinia)
- **Auth store:** Token persistence, auto-refresh every 60s
- **App store:** Toast notifications, loading states, sidebar
- Counter-based loading for nested operations

#### 3. Route Guards
```typescript
meta: {
  requiresAuth: boolean,   // Default: true
  requiresAdmin: boolean,  // Default: false
  title: string,
  titleKey?: string        // i18n key
}
```

#### 4. Composables
- `useTableLoader`: Pagination, filtering, debounced reload, AbortSignal
- `useForm`: Loading state, toast notifications, error handling
- OAuth composables for platform-specific auth flows

#### 5. i18n
- Vue-i18n Composition API mode
- Locale detection: localStorage → browser → English default
- Persistent to localStorage key `sub2api_locale`

## Critical Development Notes

### Go Version Pinning

**The Go toolchain is pinned to 1.25.5** for security reasons. Do not upgrade without following the update process in `docs/dependency-security.md`.

**Files that must stay aligned:**
- `backend/go.mod`: `go 1.25.5` + `toolchain go1.25.5`
- `backend/Dockerfile`: `GOLANG_IMAGE=golang:1.25.5-alpine`
- `.github/workflows/*.yml`: Verify `go1.25.5` in version checks

### Ent Schema Changes

When modifying database schemas:
```bash
# 1. Edit schema in backend/ent/schema/*.go
# 2. Regenerate Ent code
cd backend
go generate ./ent

# 3. Create migration (if needed)
# Manual SQL in migrations/ or use Ent auto-migration

# 4. Regenerate Wire DI (if providers changed)
go generate ./cmd/server
```

**Ent Migration Note:** Ent's auto-migration works in "append-only" mode by default - it only creates new tables/columns, doesn't drop existing ones.

### Security & Validation

- **URL Allowlist:** Upstream API hosts are validated (see `config.yaml` → `security.url_allowlist`)
- **CORS:** Configure allowed origins in `config.yaml` → `cors.allowed_origins`
- **HTTP URLs:** By default, only HTTPS is allowed. Set `allow_insecure_http: true` for development only
- **Response Headers:** Filtered by default to prevent leaking sensitive headers
- **Turnstile:** Can be required in release mode via `turnstile.required`

### Testing

- **Unit tests:** Use `-tags=unit`, no external dependencies
- **Integration tests:** Use `-tags=integration`, require testcontainers (Docker)
- **Test naming:** `TestServiceName_MethodName` or `TestServiceName_MethodName_Scenario`

### Build Tags

- `-tags embed`: Required to embed frontend assets into the binary
- `-tags unit`: Run only unit tests
- `-tags integration`: Run integration tests with testcontainers
- `-tags e2e`: Run end-to-end tests

### Environment Modes

- **Run Mode:** `standard` (full SaaS) vs `simple` (internal use, no billing)
  - Set via `RUN_MODE=simple` env var or `run_mode` in config.yaml
  - Simple mode requires `SIMPLE_MODE_CONFIRM=true` in production
  - Simple mode hides: groups, subscriptions, redeem routes
- **Server Mode:** `debug` (dev logging) vs `release` (production)

### Known Integration Issues

**Antigravity + Claude Code:**
- Plan Mode cannot exit automatically when using Antigravity
- Workaround: Press `Shift + Tab` to manually exit Plan Mode, then approve/reject
- Anthropic Claude and Antigravity Claude cannot be mixed in the same conversation context

## Configuration

- **Config file:** `deploy/config.example.yaml` (copy to `/etc/sub2api/config.yaml` or `./config.yaml`)
- **Environment variables:** Prefix with section name (e.g., `DATABASE_HOST`, `REDIS_PORT`)
- **Priority:** Environment variables override config file

### Key Configuration Sections

- `server`: Host, port, mode, trusted_proxies
- `database`: PostgreSQL connection
- `redis`: Redis connection
- `jwt`: Secret and expiration
- `security.url_allowlist`: Upstream host validation
- `gateway`: Timeouts, connection pool, concurrency settings
- `billing.circuit_breaker`: Failure threshold, reset timeout
- `gemini.quota.tiers`: Local quota simulation for Gemini

## CI/CD

- **Backend CI:** `.github/workflows/backend-ci.yml`
  - Unit tests, integration tests, golangci-lint
- **Security Scan:** `.github/workflows/security-scan.yml`
  - `govulncheck`, `gosec`, `pnpm audit`
- **Release:** `.github/workflows/release.yml`
  - Builds binaries for linux/amd64 and linux/arm64
  - Creates GitHub releases with pre-built binaries

## API Gateway Endpoints

| Endpoint | Description |
|----------|-------------|
| `/v1/messages` | Anthropic Claude API proxy |
| `/v1/chat/completions` | OpenAI-compatible proxy |
| `/v1beta/` | Gemini API proxy |
| `/antigravity/v1/messages` | Antigravity Claude endpoint |
| `/antigravity/v1beta/` | Antigravity Gemini endpoint |

## Upstream Account Types

| Type | Description |
|------|-------------|
| **API Key** | Direct API key-based accounts (Claude, OpenAI, etc.) |
| **OAuth** | Google OAuth for Gemini (Code Assist or AI Studio) |
| **Antigravity** | Antigravity OAuth accounts (hybrid scheduling support) |

## Key Coding Conventions

### Backend

1. **Always wrap errors with context:** `fmt.Errorf("operation: %w", err)`
2. **Use interface-based dependencies** for all services
3. **Implement state machines** for resources (account schedulability, circuit breaker)
4. **Leverage Redis** for distributed concerns (caching, locking, concurrency)
5. **Design for graceful degradation** (fallback pricing, non-fatal initialization)
6. **Use worker pools** for async operations (prevent unbounded goroutine growth)
7. **Preserve all fields during mutations** (token refresh preserves non-token credentials)

### Frontend

1. **Composition API with `<script setup>`** throughout
2. **Barrel exports** for convenient imports (`api/index.ts`, `stores/index.ts`)
3. **TypeScript** for all new code
4. **TailwindCSS** for styling
5. **useTableLoader** for all list views with pagination
6. **Toast notifications** via app store for user feedback

## Demo

- **URL:** https://v2.pincc.ai/
- **Credentials:** admin@sub2api.com / admin123 (shared demo, not for self-hosted)
