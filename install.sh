#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
#  MacMonitor — One-line Installer
#  Usage: curl -fsSL https://raw.githubusercontent.com/ryyansafar/MacMonitor/main/install.sh | bash
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

REPO="ryyansafar/MacMonitor"   # ← change this before pushing
APP_NAME="Macmonitor"
INSTALL_DIR="/Applications"
GITHUB_RELEASE="https://github.com/$REPO/releases/latest/download/MacMonitor.dmg"

# ── Colours ──────────────────────────────────────────────────────────────────
R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' B='\033[0;34m'
W='\033[1;37m' D='\033[2m' NC='\033[0m' BOLD='\033[1m'

header() {
    echo ""
    echo -e "${BOLD}${B}  MacMonitor Installer${NC}"
    echo -e "${D}  ────────────────────────────────────────────${NC}"
    echo ""
}

step()  { echo -e "  ${B}→${NC}  $1"; }
ok()    { echo -e "  ${G}✓${NC}  $1"; }
warn()  { echo -e "  ${Y}!${NC}  $1"; }
fail()  { echo -e "  ${R}✗${NC}  $1"; echo ""; exit 1; }

header

# ── 1. Check Apple Silicon ────────────────────────────────────────────────────
step "Checking system..."
if [[ "$(uname -m)" != "arm64" ]]; then
    fail "MacMonitor requires Apple Silicon (M1 / M2 / M3 / M4). Intel Macs are not supported."
fi

OS_VER=$(sw_vers -productVersion)
OS_MAJOR=$(echo "$OS_VER" | cut -d. -f1)
if (( OS_MAJOR < 13 )); then
    fail "macOS 13 Ventura or later is required. You have $OS_VER."
fi
ok "Apple Silicon · macOS $OS_VER"

# ── 2. Homebrew ───────────────────────────────────────────────────────────────
step "Checking Homebrew..."
if ! command -v brew &>/dev/null; then
    warn "Homebrew not found — installing it now..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add brew to PATH for Apple Silicon
    eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
fi
ok "Homebrew $(brew --version | head -1 | awk '{print $2}')"

# ── 3. mactop ─────────────────────────────────────────────────────────────────
step "Checking mactop..."
if ! command -v mactop &>/dev/null; then
    warn "Installing mactop (powers GPU, temperature & power data)..."
    brew install mactop
fi
ok "mactop $(mactop --version 2>/dev/null | head -1 || echo 'installed')"

# ── 4. Configure passwordless sudo for mactop ─────────────────────────────────
#    This means MacMonitor never prompts for a password — seamless experience.
step "Configuring passwordless sudo for mactop..."
MACTOP_PATH="$(command -v mactop)"
SUDOERS_LINE="$(whoami) ALL=(ALL) NOPASSWD: $MACTOP_PATH"
SUDOERS_FILE="/etc/sudoers.d/macmonitor"

if sudo grep -qF "$MACTOP_PATH" "$SUDOERS_FILE" 2>/dev/null; then
    ok "sudo already configured"
else
    echo "$SUDOERS_LINE" | sudo tee "$SUDOERS_FILE" > /dev/null
    sudo chmod 440 "$SUDOERS_FILE"
    ok "Passwordless sudo configured (sudo access for mactop only)"
fi

# ── 5. Download MacMonitor ────────────────────────────────────────────────────
step "Downloading MacMonitor..."
TMP_DIR=$(mktemp -d)
DMG_PATH="$TMP_DIR/MacMonitor.dmg"

if ! curl -fsSL --progress-bar "$GITHUB_RELEASE" -o "$DMG_PATH"; then
    fail "Download failed. Check your internet connection or visit: https://github.com/$REPO/releases"
fi
ok "Downloaded"

# ── 6. Install the app ────────────────────────────────────────────────────────
step "Installing $APP_NAME.app to $INSTALL_DIR..."

# Mount DMG
MOUNT_POINT=$(hdiutil attach "$DMG_PATH" -nobrowse -noautoopen | grep "/Volumes/" | awk '{print $NF}')

# Remove old version if present
if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
    warn "Removing previous version..."
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi

# Copy app
cp -R "$MOUNT_POINT/$APP_NAME.app" "$INSTALL_DIR/"

# Unmount
hdiutil detach "$MOUNT_POINT" -quiet

# Remove quarantine flag (allows running without Gatekeeper prompt)
xattr -rd com.apple.quarantine "$INSTALL_DIR/$APP_NAME.app" 2>/dev/null || true

# Cleanup
rm -rf "$TMP_DIR"
ok "Installed to $INSTALL_DIR/$APP_NAME.app"

# ── 7. Launch ────────────────────────────────────────────────────────────────
step "Launching MacMonitor..."
open "$INSTALL_DIR/$APP_NAME.app"

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "  ${G}${BOLD}All done!${NC}"
echo ""
echo -e "  MacMonitor is now running in your menu bar."
echo -e "  ${D}Look for the 🟢 indicator at the top right of your screen.${NC}"
echo ""
echo -e "  ${D}To add the desktop widget:${NC}"
echo -e "  ${D}Right-click your desktop → Edit Widgets → MacMonitor${NC}"
echo ""
echo -e "  ${D}To launch automatically on login:${NC}"
echo -e "  ${D}System Settings → General → Login Items → add MacMonitor${NC}"
echo ""
