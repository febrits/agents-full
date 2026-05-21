#!/usr/bin/env bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════╗
# ║  Agents Full — Multi-provider OpenClaw setup                ║
# ║                                                              ║
# ║  1. Export env vars for wanted providers                     ║
# ║       export OPENROUTER_API_KEY=***                    ║
# ║       export OPENAI_API_KEY=***                         ║
# ║       export ANTHROPIC_API_KEY=***                     ║
# ║       export GOOGLE_API_KEY=***                         ║
# ║       export NVIDIA_API_KEY=***                         ║
# ║       export GROQ_API_KEY=***                           ║
# ║       export TELEGRAM_BOT_TOKEN=***                     ║
# ║       export TELEGRAM_USER_ID=123456789                     ║
# ║                                                              ║
# ║  2. Run:                                                     ║
# ║       curl -fsSL https://raw.githubusercontent.com/febrits/  ║
# ║         agents-full/main/install.sh | bash                  ║
# ╚══════════════════════════════════════════════════════════════╝

INSTALL_DIR="$HOME/.openclaw"
WORKSPACE="$INSTALL_DIR/workspace"
REPO="https://raw.githubusercontent.com/febrits/agents-full/main"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail()  { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

echo ""
echo -e "${CYAN}🦉 Agents Full — Multi-Provider Setup${NC}"
echo "═══════════════════════════════════════"
echo ""

# ── Required ──────────────────────────────────────────────────
[[ -z "${TELEGRAM_BOT_TOKEN:-}" ]]  && fail "TELEGRAM_BOT_TOKEN tidak diset."
[[ -z "${TELEGRAM_USER_ID:-}" ]]   && fail "TELEGRAM_USER_ID tidak diset."

# ── Detect providers ──────────────────────────────────────────
# space-separated lists (parallel arrays)
P_ENV=() P_NAME=() P_URL=() P_TIMEOUT=() P_MODEL=()

try_add() {
  local env="$1" name="$2" url="$3" timeout="$4" model="$5"
  local val="${!env:-}"
  if [[ -n "$val" ]]; then
    P_ENV+=("$env"); P_NAME+=("$name")
    P_URL+=("$url"); P_TIMEOUT+=("$timeout"); P_MODEL+=("$model")
  fi
}

try_add OPENROUTER_API_KEY openrouter "https://openrouter.ai/api/v1"        120 "openrouter/owl-alpha"
try_add OPENAI_API_KEY     openai     "https://api.openai.com/v1"            120 "gpt-4o-mini"
try_add ANTHROPIC_API_KEY  anthropic  "https://api.anthropic.com/v1"         120 "claude-sonnet-4-20250514"
try_add GOOGLE_API_KEY     google     "https://generativelanguage.googleapis.com/v1beta" 120 "gemini-2.0-flash"
try_add NVIDIA_API_KEY     nvidia     "https://integrate.api.nvidia.com/v1"   60  "nvidia/llama-3.1-nemotron-70b-instruct"
try_add GROQ_API_KEY       groq       "https://api.groq.com/openai/v1"        60  "llama-3.3-70b-versatile"

echo -e "${CYAN}Provider detection:${NC}"
for i in "${!P_NAME[@]}"; do
  ok "  ✅ ${P_NAME[$i]}  (${P_ENV[$i]})"
done

((${#P_NAME[@]} > 0)) || fail "Tidak ada provider key yang diset. Minimal 1."
echo ""

# ── Pick primary (priority order) ─────────────────────────────
PRIMARY_IDX=0
for candidate in openrouter anthropic openai google groq nvidia; do
  for i in "${!P_NAME[@]}"; do
    [[ "${P_NAME[$i]}" == "$candidate" ]] && { PRIMARY_IDX=$i; break 2; }
  done
done

ok "Primary: ${GREEN}${P_NAME[$PRIMARY_IDX]}${NC} (${P_MODEL[$PRIMARY_IDX]})"

# ── Node.js ───────────────────────────────────────────────────
if ! command -v node &>/dev/null; then
  info "Installing Node.js 22 ..."
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi
NODE_MAJ=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
((NODE_MAJ >= 22)) || fail "Node.js $(node -v) terlalu lama. Butuh v22+."
ok "Node.js $(node -v)"

# ── OpenClaw ──────────────────────────────────────────────────
if ! command -v openclaw &>/dev/null; then
  info "Installing OpenClaw ..."
  sudo npm install -g openclaw
fi
ok "OpenClaw installed"

# ── Workspace ─────────────────────────────────────────────────
info "Setting up workspace ..."
mkdir -p "$WORKSPACE"
for f in AGENTS.md SOUL.md IDENTITY.md USER.md TOOLS.md HEARTBEAT.md; do
  curl -sfSL "$REPO/workspace/$f" -o "$WORKSPACE/$f" 2>/dev/null || true
done
ok "Workspace: $WORKSPACE"

# ── Python helper to generate JSON ────────────────────────────
# Build a data string: "env|name|url|timeout|model newline-delimited"
DATA=""
for i in "${!P_NAME[@]}"; do
  ENVV="${P_ENV[$i]}"
  DATA+="${ENVV}|${P_NAME[$i]}|${P_URL[$i]}|${P_TIMEOUT[$i]}|${P_MODEL[$i]}"$'\n'
done

# Write python script to a temp file to avoid heredoc escaping issues
PYTMP=$(mktemp /tmp/agents_setup_XXXXXX.py)
cat > "$PYTMP" << 'PYEOF'
import json, os, sys

workspace = os.environ["WORKSPACE"]
install_dir = os.environ["INSTALL_DIR"]
telegram_token = os.environ["TELEGRAM_BOT_TOKEN"]
telegram_user = os.environ["TELEGRAM_USER_ID"]
data_str = os.environ["PROVIDER_DATA"]
primary_model = os.environ["PRIMARY_MODEL"]

providers_list = []
for line in data_str.strip().split("\n"):
    if not line.strip():
        continue
    env_var, name, url, timeout, model = line.split("|")
    val = os.environ.get(env_var, "")
    providers_list.append({
        "env": env_var, "name": name, "url": url,
        "timeout": int(timeout), "model": model, "key": val
    })

config = {
    "gateway": {
        "mode": "local", "port": 18789,
        "auth": {"token": os.environ["GEN_TOKEN"]}
    },
    "env": {},
    "auth": {"profiles": {}, "order": {}},
    "models": {"providers": {}},
    "agents": {
        "defaults": {
            "workspace": workspace,
            "model": {"primary": primary_model, "fallbacks": []},
            "models": {}
        },
        "list": [
            {"id": "main", "default": True,
             "model": {"primary": primary_model, "fallbacks": []}},
            {"id": "coder",
             "model": {"primary": primary_model, "fallbacks": []}}
        ]
    },
    "channels": {
        "telegram": {
            "enabled": True, "botToken": telegram_token,
            "dmPolicy": "allowlist", "allowFrom": [telegram_user],
            "groups": {"*": {"requireMention": True}}
        }
    },
    "commands": {
        "ownerAllowFrom": [f"telegram:{telegram_user}"],
        "useAccessGroups": True
    },
    "tools": {
        "exec": {"security": "full", "ask": "off"},
        "elevated": {"enabled": True},
        "profile": "full"
    },
    "messages": {
        "groupChat": {
            "visibleReplies": "message_tool",
            "mentionPatterns": ["@openclaw", "@OpenClawBot"]
        }
    }
}

fallbacks = []
for p in providers_list:
    config["env"][p["env"]] = p["key"]
    config["models"]["providers"][p["name"]] = {
        "baseUrl": p["url"], "api": "openai-completions",
        "timeoutSeconds": p["timeout"], "models": []
    }
    config["auth"]["profiles"][f"{p['name']}:default"] = {
        "provider": p["name"], "mode": "api_key"
    }
    config["auth"]["order"][p["name"]] = [f"{p['name']}:default"]
    alias = p["model"].split("/")[-1] if "/" in p["model"] else p["model"]
    config["agents"]["defaults"]["models"][p["model"]] = {"alias": alias}
    if p["model"] != primary_model:
        fallbacks.append(p["model"])

config["agents"]["defaults"]["model"]["fallbacks"] = fallbacks
config["agents"]["list"][0]["model"]["fallbacks"] = fallbacks
config["agents"]["list"][1]["model"]["fallbacks"] = fallbacks

out = os.path.join(install_dir, "openclaw.json")
with open(out, "w") as f:
    json.dump(config, f, indent=2)
print(f"Config written to {out}")
PYEOF

# Export data for python
export INSTALL_DIR WORKSPACE
export TELEGRAM_BOT_TOKEN TELEGRAM_USER_ID
export PRIMARY_MODEL="${P_MODEL[$PRIMARY_IDX]}"
export PROVIDER_DATA="$DATA"
export GEN_TOKEN=$(head -c 64 /dev/urandom | xxd -p 2>/dev/null || date +%s%N | sha256sum | head -c 64)

# Also export all provider env vars to python
for i in "${!P_ENV[@]}"; do
  :
done

python3 "$PYTMP"
rm -f "$PYTMP"
ok "Config generated"

# ── Start gateway ─────────────────────────────────────────────
info "Starting OpenClaw gateway ..."
openclaw gateway start 2>/dev/null || openclaw gateway restart 2>/dev/null || true

echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}  🦉 Setup selesai!${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo ""
echo -e "  Providers : ${P_NAME[*]}"
echo -e "  Primary   : ${P_NAME[$PRIMARY_IDX]} (${P_MODEL[$PRIMARY_IDX]})"
((${#P_NAME[@]} > 1)) && echo -e "  Fallbacks : $(printf '%s ' "${P_MODEL[@]:$((PRIMARY_IDX+1))}")"
echo ""
echo "  openclaw status       # cek status"
echo "  openclaw logs         # lihat logs"
echo "  openclaw gateway restart  # restart"
echo ""
