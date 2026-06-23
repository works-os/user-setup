#!/usr/bin/env bash
# WorksOS Claude staff setup script (macOS).
#
# Sudo-free: installs everything into your user space — NO Mac password needed.
# Idempotent: run it, do any one-time action it asks for, then run it again.
# It never waits on a typed prompt — at each human step it explains, then exits
# so it can be re-run (so it works whether a person or Claude-in-Cowork runs it).
#
# Final state: ~/dev/works-os/frontend set up as YOUR fork (origin) with the
# real repo wired as 'upstream', deps installed, GitHub authed, ready to open
# in the Claude app's Code tab (Local).

set -euo pipefail

REPO="works-os/frontend"
WORKDIR="$HOME/dev/works-os"
TARGET_DIR="$WORKDIR/frontend"
NODE_MAJOR=22
LOCAL_BIN="$HOME/.local/bin"
ZSHRC="$HOME/.zshrc"
NVM_PIN="v0.40.1"

cyan()  { printf "\033[36m%s\033[0m\n" "$1"; }
red()   { printf "\033[31m%s\033[0m\n" "$1"; }
green() { printf "\033[32m%s\033[0m\n" "$1"; }

case "$(uname -m)" in
  arm64)  GH_ARCH=arm64 ;;
  x86_64) GH_ARCH=amd64 ;;
  *) red "Unsupported architecture: $(uname -m)"; exit 1 ;;
esac

ensure_zshrc_line() { grep -qF "$1" "$ZSHRC" 2>/dev/null || echo "$1" >> "$ZSHRC"; }

# --- Stage 1: Xcode Command Line Tools (one-time GUI click, no password) ---
if ! xcode-select -p &>/dev/null; then
  red "First, macOS needs the Command Line Tools (they provide git)."
  echo ""
  echo "A small Apple window will pop up — click \"Install\" and wait for it to finish."
  xcode-select --install 2>/dev/null || true
  echo ""
  echo "When it's done, run this setup again."
  exit 1
fi
green "✓ Command Line Tools"

# --- Stage 2: Node $NODE_MAJOR via nvm (no sudo) ---
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

node_ok=false
if command -v node &>/dev/null; then
  CUR=$(node -v | sed 's/^v//' | cut -d. -f1)
  [ "$CUR" -ge "$NODE_MAJOR" ] && { node_ok=true; green "✓ Node $(node -v)"; }
fi
if ! $node_ok; then
  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    cyan "Installing nvm (Node manager) — no password needed..."
    curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_PIN}/install.sh" | bash
    export NVM_DIR="$HOME/.nvm"
    . "$NVM_DIR/nvm.sh"
  fi
  cyan "Installing Node $NODE_MAJOR..."
  nvm install "$NODE_MAJOR" >/dev/null
  nvm alias default "$NODE_MAJOR" >/dev/null
  green "✓ Node $(node -v) installed"
fi

# --- Stage 3: GitHub CLI via tarball -> ~/.local/bin (no sudo) ---
mkdir -p "$LOCAL_BIN"
ensure_zshrc_line 'export PATH="$HOME/.local/bin:$PATH"'
export PATH="$LOCAL_BIN:$PATH"
if ! command -v gh &>/dev/null; then
  cyan "Installing GitHub CLI — no password needed..."
  GH_VER=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest \
    | grep '"tag_name"' | head -1 | sed -E 's/.*"v([^"]+)".*/\1/')
  [ -n "$GH_VER" ] || { red "Couldn't detect the latest gh version."; exit 1; }
  TMP=$(mktemp -d)
  curl -fsSL -o "$TMP/gh.zip" \
    "https://github.com/cli/cli/releases/download/v${GH_VER}/gh_${GH_VER}_macOS_${GH_ARCH}.zip"
  unzip -q "$TMP/gh.zip" -d "$TMP"
  cp "$TMP/gh_${GH_VER}_macOS_${GH_ARCH}/bin/gh" "$LOCAL_BIN/gh"
  chmod +x "$LOCAL_BIN/gh"
  rm -rf "$TMP"
  green "✓ gh CLI ${GH_VER} installed"
else
  green "✓ gh CLI $(gh --version | head -1 | awk '{print $3}')"
fi

# --- Stage 4: GitHub login (browser; no password, no token to paste) ---
if ! gh auth status &>/dev/null; then
  red "One more step: connect your GitHub account."
  echo ""
  echo "Run this (Claude can run it for you):"
  echo "    gh auth login --hostname github.com --git-protocol https --web"
  echo "It shows a one-time code — open https://github.com/login/device,"
  echo "enter the code, and authorize. Then run this setup again."
  exit 1
fi
green "✓ GitHub authenticated as $(gh api user --jq .login 2>/dev/null)"

# --- Stage 5: Fork + clone the project ---
# You're read-only on the real repo, so you work from your own fork:
#   origin   -> your fork (you can push here)
#   upstream -> $REPO (the real repo; read-only, the source of truth)
mkdir -p "$WORKDIR"
if [ -d "$TARGET_DIR/.git" ]; then
  green "✓ Project already at $TARGET_DIR"
  cd "$TARGET_DIR"
  # Make sure the real repo is wired as 'upstream' (legacy clones may lack it).
  # If 'origin' still points at the real repo instead of your fork, Claude
  # repairs that in-session — no need to untangle it here.
  if ! git remote get-url upstream &>/dev/null; then
    git remote add upstream "https://github.com/$REPO.git"
    green "✓ Linked upstream ($REPO)"
  fi
else
  cyan "Setting up your copy of the project ($REPO)..."
  # Forks to your account if you don't have one yet, clones the fork, and
  # wires 'upstream' to the real repo automatically.
  gh repo fork "$REPO" --clone -- "$TARGET_DIR"
  green "✓ Forked and cloned to $TARGET_DIR"
  cd "$TARGET_DIR"
fi

# --- Stage 6: Dependencies ---
cyan "Installing project dependencies (a few minutes the first time)..."
npm install
green "✓ Dependencies installed"

# --- Stage 7: Validate it actually works ---
cyan "Checking everything..."
fail=0
gh auth status &>/dev/null              || { red "✗ GitHub login"; fail=1; }
gh repo view "$REPO" &>/dev/null         || { red "✗ Can't reach $REPO — you may need access (ask #dev)"; fail=1; }
command -v node &>/dev/null              || { red "✗ Node"; fail=1; }
[ -d "$TARGET_DIR/node_modules" ]        || { red "✗ Dependencies"; fail=1; }
[ "$fail" -eq 0 ] || { red "Setup didn't fully complete — see the ✗ items above."; exit 1; }

green ""
green "✅ Setup confirmed — your Mac is ready."
green "   • GitHub: $(gh api user --jq .login)"
green "   • Project: $TARGET_DIR"
green ""
green "Next: open the Claude app → Code tab → New session → Local → folder $TARGET_DIR"
