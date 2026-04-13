#!/usr/bin/env bash
set -euo pipefail

# One-shot setup for optimization-ios-demo.
#
# Clones the Optimization SDK into ./optimization, installs its JS deps,
# builds the JSC bridge, and regenerates both Xcode projects.
#
#   ./scripts/setup.sh            # initial setup (idempotent)
#   ./scripts/setup.sh --update   # git pull the SDK (refuses if dirty)
#   SDK_REF=main ./scripts/setup.sh
#   SDK_REPO=git@github.com:your-fork/optimization.git ./scripts/setup.sh

SDK_REF="${SDK_REF:-NT-2874-create-ios-sdk}"
SDK_REPO="${SDK_REPO:-git@github.com:contentful/optimization.git}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK_DIR="$REPO_ROOT/optimization"
BRIDGE_DIR="$SDK_DIR/packages/ios/ios-jsc-bridge"

MODE="setup"
for arg in "$@"; do
  case "$arg" in
    --update) MODE="update" ;;
    -h|--help)
      sed -n '3,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Run with --help for usage." >&2
      exit 2
      ;;
  esac
done

if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'
else
  BOLD=""; RED=""; GREEN=""; YELLOW=""; RESET=""
fi

step() { printf "\n%s==>%s %s%s%s\n" "$GREEN" "$RESET" "$BOLD" "$1" "$RESET"; }
warn() { printf "%swarning:%s %s\n" "$YELLOW" "$RESET" "$1" >&2; }
fail() { printf "%serror:%s %s\n" "$RED" "$RESET" "$1" >&2; exit 1; }

step "Checking required tools"
missing=()
check_tool() {
  local bin="$1" hint="$2"
  if ! command -v "$bin" >/dev/null 2>&1; then
    printf "  %s✗%s %-10s missing — install with: %s\n" "$RED" "$RESET" "$bin" "$hint"
    missing+=("$bin")
  else
    printf "  %s✓%s %s\n" "$GREEN" "$RESET" "$bin"
  fi
}
check_tool git       "xcode-select --install (or brew install git)"
check_tool xcodegen  "brew install xcodegen"
check_tool node      "brew install node (or use nvm)"
check_tool pnpm      "npm install -g pnpm (or brew install pnpm)"
check_tool xcodebuild "install Xcode from the App Store"

if (( ${#missing[@]} > 0 )); then
  fail "Install the tools above and re-run this script."
fi

step "Preparing SDK working copy at $SDK_DIR"
if [[ ! -d "$SDK_DIR/.git" ]]; then
  if [[ -e "$SDK_DIR" ]]; then
    fail "$SDK_DIR exists but is not a git checkout. Move or delete it and re-run."
  fi
  echo "Cloning $SDK_REPO..."
  git clone "$SDK_REPO" "$SDK_DIR"
  echo "Checking out $SDK_REF..."
  git -C "$SDK_DIR" checkout "$SDK_REF"
else
  current_ref="$(git -C "$SDK_DIR" rev-parse --abbrev-ref HEAD)"
  if [[ "$MODE" == "update" ]]; then
    if [[ -n "$(git -C "$SDK_DIR" status --porcelain)" ]]; then
      fail "$SDK_DIR has uncommitted changes. Commit or stash them, then re-run --update."
    fi
    echo "Fetching and fast-forwarding $current_ref..."
    git -C "$SDK_DIR" fetch --prune
    git -C "$SDK_DIR" pull --ff-only
  else
    echo "SDK already cloned (on $current_ref). Pass --update to pull latest."
  fi
fi

step "Installing SDK JS dependencies (pnpm)"
(cd "$SDK_DIR" && pnpm install --frozen-lockfile)

step "Building ios-jsc-bridge"
(cd "$BRIDGE_DIR" && pnpm build)

step "Regenerating Xcode projects"
for app in SwiftUIDemo UIKitDemo; do
  echo "  xcodegen generate — $app"
  (cd "$REPO_ROOT/$app" && xcodegen generate)
done

step "Setup complete"
cat <<EOF
Open one of these workspaces in Xcode to start working:

  open $REPO_ROOT/SwiftUIDemo/SwiftUIDemo.xcworkspace
  open $REPO_ROOT/UIKitDemo/UIKitDemo.xcworkspace

To pull the latest SDK later: ./scripts/setup.sh --update
EOF
