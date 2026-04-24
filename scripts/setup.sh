#!/usr/bin/env bash
#
# remote_coding_protocol setup
#
# Safe, repeatable installer for:
# - MiniMax as the default chat model
# - Feishu as the chat channel
# - Codex via OpenClaw ACP for coding sessions
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

OPENCLAW_DIR="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"
ENV_FILE="$OPENCLAW_DIR/.env"
DEFAULT_WORKSPACE="$OPENCLAW_DIR/workspace"
CODEX_WORKSPACE_DEFAULT="$OPENCLAW_DIR/workspaces/remote-coding"
DEFAULT_FEISHU_ACCOUNT="main"
CODEX_WORKSPACE="$CODEX_WORKSPACE_DEFAULT"

log_step() {
  echo -e "${GREEN}[Step]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[Warn]${NC} $1"
}

log_error() {
  echo -e "${RED}[Error]${NC} $1" >&2
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log_error "Required command not found: $1"
    exit 1
  fi
}

ensure_state_dir() {
  mkdir -p "$OPENCLAW_DIR"
  touch "$ENV_FILE"
  chmod 600 "$ENV_FILE"
}

load_env_file() {
  if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$ENV_FILE"
    set +a
  fi
}

upsert_env_var() {
  local key="$1"
  local value="$2"
  local tmp

  tmp="$(mktemp)"
  if [ -f "$ENV_FILE" ]; then
    grep -v "^${key}=" "$ENV_FILE" >"$tmp" || true
  fi
  printf '%s=%s\n' "$key" "$value" >>"$tmp"
  mv "$tmp" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
}

unset_env_var() {
  local key="$1"
  local tmp

  tmp="$(mktemp)"
  if [ -f "$ENV_FILE" ]; then
    grep -v "^${key}=" "$ENV_FILE" >"$tmp" || true
    mv "$tmp" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
  else
    rm -f "$tmp"
  fi
}

prompt_var() {
  local key="$1"
  local label="$2"
  local secret="${3:-false}"
  local required="${4:-true}"
  local default="${5:-}"
  local current="${!key:-}"
  local prompt_suffix=""
  local reply=""

  if [ -n "$current" ]; then
    if [ "$secret" = "true" ]; then
      prompt_suffix=" [Press Enter to keep existing]"
    else
      prompt_suffix=" [${current}]"
    fi
  elif [ -n "$default" ]; then
    prompt_suffix=" [${default}]"
  fi

  while true; do
    if [ "$secret" = "true" ]; then
      read -r -s -p "${label}${prompt_suffix}: " reply
      echo ""
    else
      read -r -p "${label}${prompt_suffix}: " reply
    fi

    if [ -z "$reply" ]; then
      if [ -n "$current" ]; then
        reply="$current"
      elif [ -n "$default" ]; then
        reply="$default"
      fi
    fi

    if [ "$required" = "true" ] && [ -z "$reply" ]; then
      log_warn "${label} is required."
      continue
    fi
    break
  done

  printf -v "$key" '%s' "$reply"
  export "$key"
}

json_get_or_default() {
  local path="$1"
  local fallback="$2"
  local value

  if value="$(openclaw config get "$path" --json 2>/dev/null)"; then
    printf '%s' "$value"
  else
    printf '%s' "$fallback"
  fi
}

merge_agents() {
  local current_json="$1"
  local main_workspace="$2"
  local codex_workspace="$3"
  local output_file="$4"

  CURRENT_JSON="$current_json" MAIN_WORKSPACE="$main_workspace" CODEX_WORKSPACE="$codex_workspace" OUTPUT_FILE="$output_file" python3 - <<'PY'
import json
import os
from copy import deepcopy

current = json.loads(os.environ["CURRENT_JSON"] or "[]")
main_workspace = os.environ["MAIN_WORKSPACE"]
codex_workspace = os.environ["CODEX_WORKSPACE"]
output_file = os.environ["OUTPUT_FILE"]

patches = [
    {
        "id": "main",
        "default": True,
        "name": "Feishu Main",
        "workspace": main_workspace,
        "model": {"primary": "minimax/MiniMax-M2.7"},
    },
    {
        "id": "codex",
        "name": "Codex Worker",
        "workspace": codex_workspace,
        "runtime": {
            "type": "acp",
            "acp": {
                "agent": "codex",
                "backend": "acpx",
                "mode": "persistent",
                "cwd": codex_workspace,
            },
        },
    },
]

def deep_merge(dst, src):
    if not isinstance(dst, dict) or not isinstance(src, dict):
        return deepcopy(src)
    merged = deepcopy(dst)
    for key, value in src.items():
        if isinstance(value, dict) and isinstance(merged.get(key), dict):
            merged[key] = deep_merge(merged[key], value)
        else:
            merged[key] = deepcopy(value)
    return merged

by_id = {item.get("id"): idx for idx, item in enumerate(current) if isinstance(item, dict) and item.get("id")}
for patch in patches:
    item_id = patch["id"]
    if item_id in by_id:
        current[by_id[item_id]] = deep_merge(current[by_id[item_id]], patch)
    else:
        current.append(patch)

for item in current:
    if isinstance(item, dict) and item.get("id") == "main":
        item["default"] = True

with open(output_file, "w", encoding="utf-8") as fh:
    json.dump(current, fh, ensure_ascii=False)
PY
}

merge_bindings() {
  local current_json="$1"
  local account_id="$2"
  local codex_workspace="$3"
  local direct_open_id="${4:-}"
  local output_file="$5"

  CURRENT_JSON="$current_json" ACCOUNT_ID="$account_id" CODEX_WORKSPACE="$codex_workspace" DIRECT_OPEN_ID="$direct_open_id" OUTPUT_FILE="$output_file" python3 - <<'PY'
import json
import os
from copy import deepcopy

current = json.loads(os.environ["CURRENT_JSON"] or "[]")
account_id = os.environ["ACCOUNT_ID"]
codex_workspace = os.environ["CODEX_WORKSPACE"]
direct_open_id = os.environ["DIRECT_OPEN_ID"].strip()
output_file = os.environ["OUTPUT_FILE"]

route_binding = {
    "type": "route",
    "agentId": "main",
    "match": {"channel": "feishu", "accountId": account_id},
}

direct_binding = None
if direct_open_id:
    direct_binding = {
        "type": "acp",
        "agentId": "codex",
        "match": {
            "channel": "feishu",
            "accountId": account_id,
            "peer": {"kind": "direct", "id": direct_open_id},
        },
        "acp": {"label": "codex-feishu-dm", "cwd": codex_workspace},
    }

def binding_key(item):
    if not isinstance(item, dict):
        return None
    match = item.get("match", {})
    peer = match.get("peer") if isinstance(match, dict) else None
    if item.get("type") == "route":
        return ("route", match.get("channel"), match.get("accountId"))
    if item.get("type") == "acp":
        peer_kind = peer.get("kind") if isinstance(peer, dict) else None
        peer_id = peer.get("id") if isinstance(peer, dict) else None
        label = item.get("acp", {}).get("label") if isinstance(item.get("acp"), dict) else None
        return ("acp", match.get("channel"), match.get("accountId"), peer_kind, peer_id, label)
    return None

def deep_merge(dst, src):
    if not isinstance(dst, dict) or not isinstance(src, dict):
        return deepcopy(src)
    merged = deepcopy(dst)
    for key, value in src.items():
        if isinstance(value, dict) and isinstance(merged.get(key), dict):
            merged[key] = deep_merge(merged[key], value)
        else:
            merged[key] = deepcopy(value)
    return merged

filtered = []
for item in current:
    key = binding_key(item)
    if key and key[0] == "acp" and len(key) == 6 and key[5] == "codex-feishu-dm":
        continue
    filtered.append(item)

patches = [route_binding]
if direct_binding:
    patches.append(direct_binding)

index = {binding_key(item): idx for idx, item in enumerate(filtered) if binding_key(item) is not None}
for patch in patches:
    key = binding_key(patch)
    if key in index:
        filtered[index[key]] = deep_merge(filtered[index[key]], patch)
    else:
        filtered.append(patch)

with open(output_file, "w", encoding="utf-8") as fh:
    json.dump(filtered, fh, ensure_ascii=False)
PY
}

check_codex_login() {
  if ! codex login status >/dev/null 2>&1; then
    log_error "Codex is not logged in."
    echo "Run: codex login"
    exit 1
  fi
}

maybe_install_bubblewrap() {
  if command -v bwrap >/dev/null 2>&1; then
    echo "  bubblewrap already installed"
    return
  fi

  if [ "$(uname -s)" != "Linux" ]; then
    log_warn "bubblewrap install skipped: non-Linux host."
    return
  fi

  if ! command -v apt-get >/dev/null 2>&1; then
    log_warn "bubblewrap install skipped: apt-get not available."
    return
  fi

  log_warn "bubblewrap not found. Attempting to install with apt-get."
  if command -v sudo >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y bubblewrap
  else
    apt-get update
    apt-get install -y bubblewrap
  fi
}

configure_openclaw() {
  local agents_json
  local bindings_json
  local agents_tmp
  local bindings_tmp

  log_step "Applying OpenClaw configuration"

  openclaw config set session.dmScope per-channel-peer

  openclaw config set models.mode merge
  openclaw config set models.providers.minimax.baseUrl '${MINIMAX_BASE_URL}'
  openclaw config set models.providers.minimax.api '${MINIMAX_API_MODE}'
  openclaw config set models.providers.minimax.apiKey '${MINIMAX_API_KEY}'
  openclaw config set models.providers.minimax.models '[{"id":"MiniMax-M2.7","name":"MiniMax M2.7","reasoning":true,"input":["text","image"],"contextWindow":204800,"maxTokens":131072}]' --strict-json

  openclaw config set agents.defaults.workspace "$DEFAULT_WORKSPACE"
  openclaw config set agents.defaults.model.primary minimax/MiniMax-M2.7

  agents_json="$(json_get_or_default 'agents.list' '[]')"
  agents_tmp="$(mktemp)"
  merge_agents "$agents_json" "$DEFAULT_WORKSPACE" "$CODEX_WORKSPACE" "$agents_tmp"
  openclaw config set agents.list "$(cat "$agents_tmp")" --strict-json
  rm -f "$agents_tmp"

  openclaw config set acp.enabled true --strict-json
  openclaw config set acp.dispatch.enabled true --strict-json
  openclaw config set acp.backend acpx
  openclaw config set acp.defaultAgent codex
  openclaw config set acp.allowedAgents '["codex"]' --strict-json

  openclaw config set plugins.entries.acpx.enabled true --strict-json
  openclaw config set plugins.entries.acpx.config.permissionMode approve-all
  openclaw config set plugins.entries.acpx.config.nonInteractivePermissions fail

  openclaw config set channels.feishu.enabled true --strict-json
  openclaw config set channels.feishu.defaultAccount "$DEFAULT_FEISHU_ACCOUNT"
  openclaw config set channels.feishu.domain '${FEISHU_DOMAIN}'
  openclaw config set channels.feishu.connectionMode websocket
  openclaw config set channels.feishu.dmPolicy pairing
  openclaw config set channels.feishu.streaming true --strict-json
  openclaw config set channels.feishu.blockStreaming true --strict-json
  openclaw config set channels.feishu.accounts.main.appId '${FEISHU_APP_ID}'
  openclaw config set channels.feishu.accounts.main.appSecret '${FEISHU_APP_SECRET}'
  openclaw config set channels.feishu.accounts.main.name '${FEISHU_ACCOUNT_NAME}'

  bindings_json="$(json_get_or_default 'bindings' '[]')"
  bindings_tmp="$(mktemp)"
  merge_bindings "$bindings_json" "$DEFAULT_FEISHU_ACCOUNT" "$CODEX_WORKSPACE" "${FEISHU_DM_OPEN_ID:-}" "$bindings_tmp"
  openclaw config set bindings "$(cat "$bindings_tmp")" --strict-json
  rm -f "$bindings_tmp"
}

validate_and_restart() {
  log_step "Validating configuration"
  openclaw config validate

  log_step "Restarting gateway"
  openclaw gateway restart
}

post_install_checks() {
  log_step "Running post-install checks"
  openclaw gateway status || log_warn "Gateway status check failed."

  if openclaw secrets audit --check >/dev/null 2>&1; then
    echo "  secret audit clean"
  else
    log_warn "Secret audit reported findings. Run: openclaw secrets audit"
  fi
}

main() {
  require_command openclaw
  require_command codex
  require_command python3

  ensure_state_dir
  load_env_file
  CODEX_WORKSPACE="${REMOTE_CODING_WORKSPACE:-$CODEX_WORKSPACE_DEFAULT}"

  log_step "Checking Codex login"
  check_codex_login

  log_step "Checking bubblewrap"
  maybe_install_bubblewrap

  prompt_var REMOTE_CODING_WORKSPACE "Codex workspace path" false true "$CODEX_WORKSPACE"
  CODEX_WORKSPACE="$REMOTE_CODING_WORKSPACE"

  mkdir -p "$DEFAULT_WORKSPACE" "$CODEX_WORKSPACE"

  prompt_var MINIMAX_API_KEY "MiniMax API key" true true
  prompt_var MINIMAX_BASE_URL "MiniMax base URL" false true "https://api.minimax.io/anthropic"
  prompt_var MINIMAX_API_MODE "MiniMax API mode" false true "anthropic-messages"
  prompt_var FEISHU_APP_ID "Feishu App ID" false true
  prompt_var FEISHU_APP_SECRET "Feishu App Secret" true true
  prompt_var FEISHU_DOMAIN "Feishu domain (feishu or lark)" false true "feishu"
  prompt_var FEISHU_ACCOUNT_NAME "Feishu bot display name" false true "Remote Coding Bot"
  prompt_var GITHUB_TOKEN "GitHub token for git push helpers (optional)" true false
  prompt_var FEISHU_DM_OPEN_ID "Optional Feishu open_id for direct Codex DM binding" false false

  log_step "Updating OpenClaw environment file"
  upsert_env_var MINIMAX_API_KEY "$MINIMAX_API_KEY"
  upsert_env_var MINIMAX_BASE_URL "$MINIMAX_BASE_URL"
  upsert_env_var MINIMAX_API_MODE "$MINIMAX_API_MODE"
  upsert_env_var FEISHU_APP_ID "$FEISHU_APP_ID"
  upsert_env_var FEISHU_APP_SECRET "$FEISHU_APP_SECRET"
  upsert_env_var FEISHU_DOMAIN "$FEISHU_DOMAIN"
  upsert_env_var FEISHU_ACCOUNT_NAME "$FEISHU_ACCOUNT_NAME"
  upsert_env_var REMOTE_CODING_WORKSPACE "$REMOTE_CODING_WORKSPACE"
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    upsert_env_var GITHUB_TOKEN "$GITHUB_TOKEN"
  fi
  if [ -n "${FEISHU_DM_OPEN_ID:-}" ]; then
    upsert_env_var FEISHU_DM_OPEN_ID "$FEISHU_DM_OPEN_ID"
  else
    unset_env_var FEISHU_DM_OPEN_ID
  fi

  configure_openclaw
  validate_and_restart
  post_install_checks

  echo ""
  echo -e "${GREEN}Setup complete.${NC}"
  echo ""
  echo "Config file: $(openclaw config file)"
  echo "Env file:    $ENV_FILE"
  echo "Workspace:   $CODEX_WORKSPACE"
  echo ""
  echo "Default flow:"
  echo "  1. Start with a normal Feishu DM to the main agent"
  echo "  2. Run: /acp doctor"
  echo "  3. Run: /acp spawn codex --thread here"
  echo "  4. Send a coding request in that bound thread"
  echo ""
  if [ -n "${FEISHU_DM_OPEN_ID:-}" ]; then
    echo "Direct DM binding was configured for: ${FEISHU_DM_OPEN_ID}"
  else
    echo "No direct DM-to-Codex binding was created."
  fi
  echo ""
  log_warn "If Codex sandbox still fails in your host environment, handle that as a host-specific deployment issue."
  log_warn "This installer does not force vendor-side sandbox bypass flags."
}

main "$@"
