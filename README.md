# 🦉 Agents Full — Multi-Provider OpenClaw Setup

Non-interactive installer with **multi-provider support**. Export keys for whichever providers you want — auto-detects and configures them.

## Quick Install

```bash
export OPENROUTER_API_KEY=***
export TELEGRAM_BOT_TOKEN=***
export TELEGRAM_USER_ID=123456789

# Optional — add as many as you want:
export OPENAI_API_KEY=***
export ANTHROPIC_API_KEY=***
export GOOGLE_API_KEY=***
export NVIDIA_API_KEY=***
export GROQ_API_KEY=***

curl -fsSL https://raw.githubusercontent.com/febrits/agents-full/main/install.sh | bash
```

## Supported Providers

| Provider | Env Var | Default Model | Timeout |
|----------|---------|---------------|---------|
| OpenRouter | `OPENROUTER_API_KEY` | `openrouter/owl-alpha` | 120s |
| OpenAI | `OPENAI_API_KEY` | `gpt-4o-mini` | 120s |
| Anthropic | `ANTHROPIC_API_KEY` | `claude-sonnet-4-20250514` | 120s |
| Google | `GOOGLE_API_KEY` | `gemini-2.0-flash` | 120s |
| NVIDIA | `NVIDIA_API_KEY` | `nvidia/llama-3.1-nemotron-70b-instruct` | 60s |
| Groq | `GROQ_API_KEY` | `llama-3.3-70b-versatile` | 60s |

## How It Works

1. **Detects** which providers you have keys for
2. **Picks primary** by priority: OpenRouter > Anthropic > OpenAI > Google > Groq > NVIDIA
3. **Sets fallbacks** to all other detected providers
4. **Generates** `~/.openclaw/openclaw.json` automatically
5. **Starts** OpenClaw gateway

## Custom Models

Override default models before running:

```bash
export OPENAI_MODEL=gpt-4o
export ANTHROPIC_MODEL=claude-opus-4-20250514
export GOOGLE_MODEL=gemini-2.5-pro
```

## After Install

```bash
openclaw status           # check status
openclaw logs             # view logs
openclaw gateway restart  # restart
```
