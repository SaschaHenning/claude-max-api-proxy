# Claude Max API Proxy

**Use your Claude Max subscription ($200/month) with any OpenAI-compatible client — no separate API costs!**

This provider wraps the Claude Code CLI as a subprocess and exposes an OpenAI-compatible HTTP API, allowing tools like Clawdbot, Continue.dev, or any OpenAI-compatible client to use your Claude Max subscription instead of paying per-API-call.

> **This fork** adds Docker support and Portainer deployment instructions for self-hosting on Proxmox / any Docker host.

## Why This Exists

| Approach | Cost | Limitation |
|----------|------|------------|
| Claude API | ~$15/M input, ~$75/M output tokens | Pay per use |
| Claude Max | $200/month flat | OAuth blocked for third-party API use |
| **This Provider** | $0 extra (uses Max subscription) | Routes through CLI |

Anthropic blocks OAuth tokens from being used directly with third-party API clients. However, the Claude Code CLI *can* use OAuth tokens. This provider bridges that gap by wrapping the CLI and exposing a standard API.

## How It Works

```
Your App (Clawdbot, etc.)
         ↓
    HTTP Request (OpenAI format)
         ↓
   Claude Code CLI Provider (this project)
         ↓
   Claude Code CLI (subprocess)
         ↓
   OAuth Token (from Max subscription)
         ↓
   Anthropic API
         ↓
   Response → OpenAI format → Your App
```

## Features

- **OpenAI-compatible API** — Works with any client that supports OpenAI's API format
- **Streaming support** — Real-time token streaming via Server-Sent Events
- **Multiple models** — Claude Opus, Sonnet, and Haiku
- **Session management** — Maintains conversation context
- **Docker ready** — Run as a container on Proxmox, Synology, or any Docker host
- **Portainer Stack** — One-click deployment via Portainer
- **Zero configuration** — Uses existing Claude CLI authentication
- **Secure by design** — Uses spawn() to prevent shell injection

---

## Docker Deployment (Recommended)

### Prerequisites

- **Claude Max subscription** ($200/month) — [Subscribe here](https://claude.ai)
- **Docker** and **Docker Compose** on your host (Proxmox LXC, VM, bare-metal, etc.)

### Option A: Portainer Stack (Recommended for Proxmox)

1. Open **Portainer** → **Stacks** → **Add Stack**
2. Name: `claude-max-api-proxy`
3. Select **Repository** as build method:
   - **Repository URL**: `https://github.com/SaschaHenning/claude-max-api-proxy`
   - **Repository reference**: `refs/heads/main`
   - **Compose path**: `docker-compose.yml`
4. Click **Deploy the stack**
5. Wait for the build to complete (first build takes ~1–2 minutes)

Alternatively, paste this **docker-compose** directly into the Portainer **Web editor**:

```yaml
services:
  claude-proxy:
    build: .
    container_name: claude-max-api-proxy
    restart: unless-stopped
    ports:
      - "3456:3456"
    volumes:
      - claude-config:/root/.claude
    environment:
      - PORT=3456
      - HOST=0.0.0.0

volumes:
  claude-config:
```

> **Note:** If using the Web editor, Portainer cannot build from source. Use a pre-built image or deploy via Repository / CLI instead.

### Option B: Docker Compose (CLI)

```bash
git clone https://github.com/SaschaHenning/claude-max-api-proxy.git
cd claude-max-api-proxy
docker compose up -d
```

### Option C: Docker Run

```bash
docker build -t claude-max-api-proxy .
docker run -d \
  --name claude-max-api-proxy \
  --restart unless-stopped \
  -p 3456:3456 \
  -v claude-config:/root/.claude \
  -e HOST=0.0.0.0 \
  -e PORT=3456 \
  claude-max-api-proxy
```

### Authenticate Claude CLI (Required Once)

After the container is running, authenticate with your Claude Max account:

```bash
docker exec -it claude-max-api-proxy claude auth login
```

This opens an interactive prompt. Since the container is headless, the CLI will display a URL — open that URL in a browser on any device, complete the login, and the token is stored in the persistent volume.

Credentials are saved in the `claude-config` Docker volume and survive container restarts and rebuilds.

### Verify It Works

```bash
# Health check (replace with your Docker host IP)
curl http://<host-ip>:3456/health

# List models
curl http://<host-ip>:3456/v1/models

# Chat completion
curl -X POST http://<host-ip>:3456/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `3456` | Server port |
| `HOST` | `0.0.0.0` | Bind address (`0.0.0.0` for Docker, `127.0.0.1` for local-only) |

---

## Local Installation (without Docker)

### Prerequisites

1. **Claude Max subscription** ($200/month) — [Subscribe here](https://claude.ai)
2. **Claude Code CLI** installed and authenticated:
   ```bash
   npm install -g @anthropic-ai/claude-code
   claude auth login
   ```

### Install & Run

```bash
git clone https://github.com/SaschaHenning/claude-max-api-proxy.git
cd claude-max-api-proxy
npm install
npm run build
node dist/server/standalone.js
```

The server runs at `http://localhost:3456` by default.

---

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/v1/models` | GET | List available models |
| `/v1/chat/completions` | POST | Chat completions (streaming & non-streaming) |

## Available Models

| Model ID | Maps To |
|----------|---------|
| `claude-opus-4` | Claude Opus 4.5 |
| `claude-sonnet-4` | Claude Sonnet 4 |
| `claude-haiku-4` | Claude Haiku 4 |

## Configuration with Popular Tools

### Continue.dev

Add to your Continue config:

```json
{
  "models": [{
    "title": "Claude (Max)",
    "provider": "openai",
    "model": "claude-opus-4",
    "apiBase": "http://<host-ip>:3456/v1",
    "apiKey": "not-needed"
  }]
}
```

### Generic OpenAI Client (Python)

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://<host-ip>:3456/v1",
    api_key="not-needed"  # Any value works
)

response = client.chat.completions.create(
    model="claude-opus-4",
    messages=[{"role": "user", "content": "Hello!"}]
)
```

### n8n / Other Automation

Use the **HTTP Request** node or any OpenAI-compatible integration with:
- **Base URL**: `http://<host-ip>:3456/v1`
- **API Key**: any non-empty string (e.g. `not-needed`)

## Architecture

```
src/
├── types/
│   ├── claude-cli.ts      # Claude CLI JSON output types
│   └── openai.ts          # OpenAI API types
├── adapter/
│   ├── openai-to-cli.ts   # Convert OpenAI requests → CLI format
│   └── cli-to-openai.ts   # Convert CLI responses → OpenAI format
├── subprocess/
│   └── manager.ts         # Claude CLI subprocess management
├── session/
│   └── manager.ts         # Session ID mapping
├── server/
│   ├── index.ts           # Express server setup
│   ├── routes.ts          # API route handlers
│   └── standalone.ts      # Entry point
└── index.ts               # Package exports

Docker files:
├── Dockerfile             # Multi-stage build (build + runtime)
├── docker-compose.yml     # Compose stack for Portainer / CLI
├── entrypoint.sh          # Container startup script
└── .dockerignore          # Build context filter
```

## Security

- Uses Node.js `spawn()` instead of shell execution to prevent injection attacks
- No API keys stored or transmitted by this provider
- All authentication handled by Claude CLI's secure credential storage
- Prompts passed as CLI arguments, not through shell interpretation

## Troubleshooting

### "Claude CLI not found" (Docker)

The CLI is bundled in the Docker image. If you see this error, the image may not have built correctly. Rebuild with:
```bash
docker compose build --no-cache
```

### Authentication fails in Docker

Re-run the auth command and follow the URL prompt:
```bash
docker exec -it claude-max-api-proxy claude auth login
```

### Server not reachable from other machines

Ensure `HOST=0.0.0.0` is set (default in Docker). If you're behind a firewall, open port `3456`.

### Streaming returns immediately with no content

Ensure you're using `-N` flag with curl (disables buffering):
```bash
curl -N -X POST http://<host-ip>:3456/v1/chat/completions ...
```

## License

MIT

## Acknowledgments

- Original project by [atalovesyou](https://github.com/atalovesyou/claude-max-api-proxy)
- Built for use with [Clawdbot](https://clawd.bot)
- Powered by [Claude Code CLI](https://github.com/anthropics/claude-code)
