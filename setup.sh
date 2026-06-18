#!/usr/bin/env bash
# WorksOS Claude staff setup script.
# Idempotent: run it, follow any prompts (install Xcode CLT, run gh auth login),
# then re-run. Each run advances as far as it can given current state.
# Final state: ~/dev/works-os/frontend exists, dependencies installed, ready for Claude.

set -euo pipefail

REPO="works-os/frontend"
TARGET_DIR="$HOME/dev/works-os/frontend"
MIN_NODE_MAJOR=22

cyan()  { printf "\033[36m%s\033[0m\n" "$1"; }
red()   { printf "\033[31m%s\033[0m\n" "$1"; }
green() { printf "\033[32m%s\033[0m\n" "$1"; }

case "$(uname -m)" in
  arm64)  GH_ARCH=arm64 ;;
  x86_64) GH_ARCH=amd64 ;;
  *) red "Unsupported architecture: $(uname -m)"; exit 1 ;;
esac

# --- Stage 1: Xcode Command Line Tools (manual install) ---
if ! xcode-select -p &>/dev/null; then
  red "Xcode Command Line Tools are not installed."
  echo ""
  echo "Run this in Terminal, click through the GUI prompt, and wait for the install to finish:"
  echo "  xcode-select --install"
  echo ""
  echo "Then re-run this setup script."
  exit 1
fi
green "✓ Xcode Command Line Tools"

# --- Stage 2: Node 22+ ---
node_ok=false
if command -v node &>/dev/null; then
  NODE_MAJOR=$(node -v | sed 's/^v//' | cut -d. -f1)
  if [ "$NODE_MAJOR" -ge "$MIN_NODE_MAJOR" ]; then
    node_ok=true
    green "✓ Node $(node -v)"
  else
    cyan "Node $MIN_NODE_MAJOR+ required (you have $(node -v)). Installing newer version..."
  fi
fi

if ! $node_ok; then
  cyan "Installing Node $MIN_NODE_MAJOR LTS (may prompt for your Mac password)..."
  NODE_VERSION=$(curl -fsSL "https://nodejs.org/dist/latest-v22.x/" \
    | grep -oE "node-v22\.[0-9]+\.[0-9]+\.pkg" | head -1 | sed 's/node-//;s/\.pkg//')
  if [ -z "$NODE_VERSION" ]; then
    red "Failed to detect latest Node 22.x version from nodejs.org."
    red "Install Node 22 LTS manually from https://nodejs.org/ and re-run."
    exit 1
  fi
  NODE_PKG="/tmp/node-${NODE_VERSION}.pkg"
  curl -fsSL -o "$NODE_PKG" "https://nodejs.org/dist/latest-v22.x/node-${NODE_VERSION}.pkg"
  sudo installer -pkg "$NODE_PKG" -target /
  rm -f "$NODE_PKG"
  green "✓ Node ${NODE_VERSION} installed"
fi

# --- Stage 3: GitHub CLI ---
if ! command -v gh &>/dev/null; then
  cyan "Installing GitHub CLI (may prompt for your Mac password)..."
  GH_VERSION=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest \
    | grep '"tag_name"' | head -1 | sed -E 's/.*"v([^"]+)".*/\1/')
  if [ -z "$GH_VERSION" ]; then
    red "Failed to detect latest gh CLI version."
    red "Install gh CLI manually from https://cli.github.com/ and re-run."
    exit 1
  fi
  GH_PKG="/tmp/gh_${GH_VERSION}_macOS_${GH_ARCH}.pkg"
  curl -fsSL -o "$GH_PKG" \
    "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_macOS_${GH_ARCH}.pkg"
  sudo installer -pkg "$GH_PKG" -target /
  rm -f "$GH_PKG"
  green "✓ gh CLI ${GH_VERSION} installed"
else
  green "✓ gh CLI $(gh --version | head -1 | awk '{print $3}')"
fi

# --- Stage 4: gh auth (manual login) ---
if ! gh auth status &>/dev/null; then
  red "GitHub CLI is not authenticated."
  echo ""
  echo "Run this in Terminal, follow the browser prompts, and finish the login:"
  echo "  gh auth login"
  echo ""
  echo "Then re-run this setup script."
  exit 1
fi
green "✓ gh authenticated"

# --- Stage 5: Clone repo ---
mkdir -p "$HOME/dev/works-os"
if [ -d "$TARGET_DIR" ]; then
  green "✓ Repo already cloned at $TARGET_DIR"
else
  cyan "Cloning $REPO..."
  gh repo clone "$REPO" "$TARGET_DIR"
  green "✓ Cloned"
fi

cd "$TARGET_DIR"

# --- Stage 6: npm install ---
cyan "Running npm install (may take a few minutes)..."
npm install
green "✓ Dependencies installed"

green ""
green "Setup complete."
green ""
green "Next steps:"
green "  1. Open Claude desktop app"
green "  2. Click the Code tab"
green "  3. New session"
green "  4. Environment: Local"
green "  5. Project folder: $TARGET_DIR"
green ""
