#!/bin/bash
#
# remote_coding_protocol Setup Script
# Usage: bash setup.sh
#
# This script sets up the OpenClaw + Codex ACP environment for remote coding.
# It will prompt for GitHub token if not already configured.
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

OPENCLAW_DIR="$HOME/.openclaw"
SKILL_DIR="$OPENCLAW_DIR/skills/remote_coding_protocol"
WORKSPACES_DIR="$OPENCLAW_DIR/workspaces/codex-test"
CONFIG_FILE="$OPENCLAW_DIR/openclaw.json"

echo_step() {
  echo -e "${GREEN}[Step]${NC} $1"
}

echo_warn() {
  echo -e "${YELLOW}[Warn]${NC} $1"
}

echo_error() {
  echo -e "${RED}[Error]${NC} $1"
}

# ============================================================================
# Step 1: Check and install bubblewrap
# ============================================================================
echo_step "Checking bubblewrap installation..."

if command -v bwrap &> /dev/null; then
  echo "  bubblewrap already installed: $(bwrap --version)"
else
  echo "  bubblewrap not found, installing..."
  if command -v sudo &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y bubblewrap
  else
    apt-get update && apt-get install -y bubblewrap
  fi
  echo "  bubblewrap installed successfully"
fi

# ============================================================================
# Step 2: Check Codex login status
# ============================================================================
echo_step "Checking Codex login status..."

CODEX_AUTH_FILE="$HOME/.codex/auth.json"
if [ -f "$CODEX_AUTH_FILE" ]; then
  AUTH_MODE=$(grep -o '"auth_mode":"[^"]*"' "$CODEX_AUTH_FILE" 2>/dev/null | cut -d'"' -f4 || echo "unknown")
  echo "  Codex is logged in (mode: $AUTH_MODE)"

  # Check if token is expired
  if grep -q '"expires"' "$CODEX_AUTH_FILE" 2>/dev/null; then
    EXPIRES=$(grep '"expires"' "$CODEX_AUTH_FILE" | grep -oP '"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}' | head -1)
    echo "  Token expires: $EXPIRES"
  fi
else
  echo_error "Codex is NOT logged in!"
  echo ""
  echo "  Please run the following command to login:"
  echo "    codex login"
  echo ""
  echo "  After login, run this script again."
  exit 1
fi

# ============================================================================
# Step 3: Check GitHub Token
# ============================================================================
echo_step "Checking GitHub Token..."

# Try to read from existing config first
GITHUB_TOKEN=""
if [ -f "$CONFIG_FILE" ]; then
  EXISTING_TOKEN=$(grep -o '"GITHUB_TOKEN":"[^"]*"' "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f4)
  if [ -n "$EXISTING_TOKEN" ]; then
    GITHUB_TOKEN="$EXISTING_TOKEN"
    echo "  Found existing GitHub Token in config"
  fi
fi

# If no token found, prompt user
if [ -z "$GITHUB_TOKEN" ]; then
  echo ""
  echo "  No GitHub Token found in config."
  echo "  Please provide your GitHub Personal Access Token."
  echo "  (Need 'repo' permission for push access)"
  echo ""
  echo -n "  GitHub Token: "
  read -r GITHUB_TOKEN

  if [ -z "$GITHUB_TOKEN" ]; then
    echo_error "GitHub Token is required. Setup cancelled."
    exit 1
  fi
fi

# Validate token format
if [[ ! "$GITHUB_TOKEN" =~ ^ghp_ ]]; then
  echo_warn "Token doesn't look like a GitHub PAT (should start with ghp_)"
  echo -n "  Continue anyway? (y/N): "
  read -r confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 1
  fi
fi

# ============================================================================
# Step 4: Create directories
# ============================================================================
echo_step "Creating workspace directories..."

mkdir -p "$WORKSPACES_DIR"
echo "  Workspace: $WORKSPACES_DIR"

# ============================================================================
# Step 5: Get Feishu user ID from existing config or prompt
# ============================================================================
echo_step "Checking Feishu configuration..."

FEISHU_USER_ID=""
if [ -f "$CONFIG_FILE" ]; then
  # Try to extract from existing bindings
  FEISHU_USER_ID=$(grep -o '"id":"ou_[^"]*"' "$CONFIG_FILE" 2>/dev/null | head -1 | cut -d'"' -f4)
  if [ -n "$FEISHU_USER_ID" ]; then
    echo "  Found Feishu user ID: $FEISHU_USER_ID"
  fi
fi

if [ -z "$FEISHU_USER_ID" ]; then
  echo ""
  echo "  Please provide your Feishu Open ID for DM binding."
  echo "  (You can find it in OpenClaw logs or Feishu bot settings)"
  echo ""
  echo -n "  Feishu Open ID (ou_xxx): "
  read -r FEISHU_USER_ID

  if [ -z "$FEISHU_USER_ID" ]; then
    echo_warn "No Feishu user ID provided, using default binding method"
    FEISHU_USER_ID="ou_b5cd015316fce96537e3def26e513822"  # Will be replaced by actual
  fi
fi

# ============================================================================
# Step 6: Backup existing config
# ============================================================================
if [ -f "$CONFIG_FILE" ]; then
  BACKUP_FILE="$CONFIG_FILE.bak.$(date +%Y%m%d%H%M%S)"
  cp "$CONFIG_FILE" "$BACKUP_FILE"
  echo_step "Backed up existing config to: $BACKUP_FILE"
fi

# ============================================================================
# Step 7: Generate openclaw.json
# ============================================================================
echo_step "Generating OpenClaw configuration..."

cat > "$CONFIG_FILE" << 'EOF'
{
  "meta": {
    "lastTouchedVersion": "2026.3.28",
    "lastTouchedAt": "2026-03-31T18:16:17.195Z"
  },
  "wizard": {
    "lastRunAt": "2026-03-31T18:16:17.164Z",
    "lastRunVersion": "2026.3.28",
    "lastRunCommand": "configure",
    "lastRunMode": "local"
  },
  "auth": {
    "profiles": {
      "minimax:cn": {
        "provider": "minimax",
        "mode": "api_key"
      }
    }
  },
  "env": {
    "GITHUB_TOKEN": "GITHUB_TOKEN_PLACEHOLDER"
  },
  "models": {
    "mode": "merge",
    "providers": {
      "minimax": {
        "baseUrl": "https://api.minimaxi.com/anthropic",
        "api": "anthropic-messages",
        "authHeader": true,
        "models": [
          {
            "id": "MiniMax-M2.7",
            "name": "MiniMax M2.7",
            "reasoning": true,
            "input": ["text"],
            "cost": {
              "input": 0.3,
              "output": 1.2,
              "cacheRead": 0.06,
              "cacheWrite": 0.375
            },
            "contextWindow": 204800,
            "maxTokens": 131072
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "minimax/MiniMax-M2.7"
      },
      "models": {
        "minimax/MiniMax-M2.7": {
          "alias": "Minimax"
        }
      },
      "workspace": "WORKSPACE_DEFAULT"
    },
    "list": [
      {
        "id": "main",
        "default": true,
        "name": "Feishu Main",
        "workspace": "WORKSPACE_DEFAULT",
        "model": {
          "primary": "minimax/MiniMax-M2.7"
        }
      },
      {
        "id": "codex",
        "name": "Codex Worker",
        "workspace": "WORKSPACE_CODEX",
        "model": {
          "primary": "minimax/MiniMax-M2.7"
        },
        "runtime": {
          "type": "acp",
          "acp": {
            "agent": "codex",
            "backend": "acpx",
            "mode": "persistent",
            "cwd": "WORKSPACE_CODEX"
          }
        }
      }
    ]
  },
  "tools": {
    "profile": "coding",
    "web": {
      "search": {
        "provider": "brave"
      }
    }
  },
  "commands": {
    "native": "auto",
    "nativeSkills": "auto",
    "restart": true,
    "ownerDisplay": "raw"
  },
  "session": {
    "dmScope": "per-channel-peer"
  },
  "acp": {
    "enabled": true,
    "dispatch": {
      "enabled": true
    },
    "backend": "acpx",
    "defaultAgent": "codex",
    "allowedAgents": ["codex"]
  },
  "bindings": [
    {
      "type": "route",
      "agentId": "main",
      "match": {
        "channel": "feishu",
        "accountId": "main"
      }
    },
    {
      "type": "acp",
      "agentId": "codex",
      "match": {
        "channel": "feishu",
        "accountId": "main",
        "peer": {
          "kind": "direct",
          "id": "FEISHU_USER_ID_PLACEHOLDER"
        }
      },
      "acp": {
        "label": "codex-feishu-dm",
        "cwd": "WORKSPACE_CODEX"
      }
    }
  ],
  "channels": {
    "feishu": {
      "enabled": true,
      "appId": "FEISHU_APP_ID_PLACEHOLDER",
      "appSecret": "FEISHU_APP_SECRET_PLACEHOLDER",
      "connectionMode": "websocket",
      "domain": "feishu",
      "groupPolicy": "allowlist",
      "groupAllowFrom": [
        "oc_46753e08b6bf947e3aa7dd8a511d54e7"
      ],
      "webhookPath": "/feishu/events",
      "dmPolicy": "pairing",
      "reactionNotifications": "own",
      "typingIndicator": true,
      "resolveSenderNames": true
    }
  },
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "loopback",
    "controlUi": {
      "allowInsecureAuth": true
    },
    "auth": {
      "mode": "token",
      "token": "GATEWAY_TOKEN_PLACEHOLDER"
    },
    "tailscale": {
      "mode": "off",
      "resetOnExit": false
    },
    "nodes": {
      "denyCommands": [
        "camera.snap",
        "camera.clip",
        "screen.record",
        "contacts.add",
        "calendar.add",
        "reminders.add",
        "sms.send"
      ]
    }
  },
  "plugins": {
    "entries": {
      "feishu": {
        "enabled": true,
        "config": {}
      },
      "acpx": {
        "enabled": true,
        "config": {
          "permissionMode": "approve-all",
          "nonInteractivePermissions": "fail"
        }
      }
    }
  }
}
EOF

# Replace placeholders
sed -i "s|GITHUB_TOKEN_PLACEHOLDER|$GITHUB_TOKEN|g" "$CONFIG_FILE"
sed -i "s|FEISHU_USER_ID_PLACEHOLDER|$FEISHU_USER_ID|g" "$CONFIG_FILE"
sed -i "s|WORKSPACE_DEFAULT|$HOME/.openclaw/workspace|g" "$CONFIG_FILE"
sed -i "s|WORKSPACE_CODEX|$WORKSPACES_DIR|g" "$CONFIG_FILE"
sed -i "s|FEISHU_APP_ID_PLACEHOLDER|cli_a94041037678dcd2|g" "$CONFIG_FILE"
sed -i "s|FEISHU_APP_SECRET_PLACEHOLDER|60iJBHmVfFtukhevoXhyNc5lBcbKXrYI|g" "$CONFIG_FILE"
sed -i "s|GATEWAY_TOKEN_PLACEHOLDER|f66a5308d97c15147bd7b582c3dbbcd79a925887dec8d8ff|g" "$CONFIG_FILE"

echo "  Config written to: $CONFIG_FILE"

# ============================================================================
# Step 8: Validate config
# ============================================================================
echo_step "Validating OpenClaw configuration..."

if command -v openclaw &> /dev/null; then
  VALIDATE_RESULT=$(openclaw config validate 2>&1)
  if echo "$VALIDATE_RESULT" | grep -q "Config valid"; then
    echo "  ✅ Config validation passed"
  else
    echo_error "Config validation failed:"
    echo "$VALIDATE_RESULT"
    exit 1
  fi
else
  echo_warn "openclaw command not found, skipping validation"
fi

# ============================================================================
# Step 9: Restart gateway
# ============================================================================
echo_step "Restarting OpenClaw Gateway..."

if command -v openclaw &> /dev/null; then
  openclaw gateway restart 2>&1 || true
  sleep 2
  echo "  Gateway restart initiated"
else
  echo_warn "openclaw command not found, please restart manually"
fi

# ============================================================================
# Done
# ============================================================================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Setup Complete! 🎉${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Test in Feishu: send '/acp spawn codex'"
echo "  2. Then try a coding task like:"
echo "     '创建 hello.py，输出 Hello World'"
echo ""
echo "For session management:"
echo "  /acp status   - check session status"
echo "  /acp close    - close current session"
echo ""
