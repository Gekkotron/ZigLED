#!/usr/bin/env bash
# ZigLED toolchain installer.
# Installs Zig and ESP-IDF v5.3.2 for esp32c6. Idempotent — safe to re-run.
# Does not modify shell rc files; prints the line to add yourself.

set -euo pipefail

ESP_IDF_VERSION="v5.3.2"
ESP_IDF_DIR="${HOME}/esp/esp-idf"
ZIG_MIN_MAJOR=0
ZIG_MIN_MINOR=14
TARGET_CHIP="esp32c6"

BOLD=$(tput bold 2>/dev/null || echo "")
DIM=$(tput dim 2>/dev/null || echo "")
GREEN=$(tput setaf 2 2>/dev/null || echo "")
YELLOW=$(tput setaf 3 2>/dev/null || echo "")
RED=$(tput setaf 1 2>/dev/null || echo "")
RESET=$(tput sgr0 2>/dev/null || echo "")

step()   { printf "\n%s==>%s %s%s%s\n" "$GREEN" "$RESET" "$BOLD" "$*" "$RESET"; }
info()   { printf "    %s\n" "$*"; }
warn()   { printf "%s%s%s\n" "$YELLOW" "$*" "$RESET"; }
die()    { printf "%s%s%s\n" "$RED" "$*" "$RESET" >&2; exit 1; }

require_cmd() {
    local cmd="$1"
    local hint="$2"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        die "Missing '$cmd'. $hint"
    fi
}

version_ge() {
    # $1 >= $2  (semver-ish)
    [ "$1" = "$2" ] && return 0
    local IFS=.
    local a=($1) b=($2)
    for ((i=0; i<${#b[@]}; i++)); do
        local ai=${a[i]:-0}
        local bi=${b[i]:-0}
        if (( ai > bi )); then return 0; fi
        if (( ai < bi )); then return 1; fi
    done
    return 0
}

step "Checking macOS prerequisites"
if [ "$(uname -s)" != "Darwin" ]; then
    warn "This installer targets macOS. On Linux, run ESP-IDF's install.sh directly and install Zig via your distro."
fi
require_cmd git    "Install Xcode Command Line Tools: xcode-select --install"
require_cmd python3 "Install Python 3 (system Python 3 on modern macOS should suffice)."
require_cmd brew   "Install Homebrew: https://brew.sh/"

step "Installing Zig via Homebrew"
if command -v zig >/dev/null 2>&1; then
    zig_version="$(zig version)"
    info "Found zig $zig_version"
    minver="${ZIG_MIN_MAJOR}.${ZIG_MIN_MINOR}.0"
    if version_ge "$zig_version" "$minver"; then
        info "Version >= $minver, skipping."
    else
        warn "Zig $zig_version is below required $minver. Upgrading via Homebrew."
        brew upgrade zig
    fi
else
    brew install zig
    info "Installed zig $(zig version)"
fi

step "Cloning ESP-IDF ${ESP_IDF_VERSION}"
mkdir -p "$(dirname "$ESP_IDF_DIR")"
if [ -d "$ESP_IDF_DIR/.git" ]; then
    info "ESP-IDF already present at $ESP_IDF_DIR"
    current_tag="$(git -C "$ESP_IDF_DIR" describe --tags 2>/dev/null || echo unknown)"
    info "Current checkout: $current_tag"
    if [ "$current_tag" != "$ESP_IDF_VERSION" ]; then
        warn "Existing checkout is not $ESP_IDF_VERSION. Leaving it alone."
        warn "If you want to switch, run manually:"
        warn "  cd $ESP_IDF_DIR && git fetch --tags && git checkout $ESP_IDF_VERSION && git submodule update --init --recursive"
    fi
else
    info "Cloning into $ESP_IDF_DIR"
    git clone -b "$ESP_IDF_VERSION" --recursive https://github.com/espressif/esp-idf.git "$ESP_IDF_DIR"
fi

step "Running ESP-IDF install for $TARGET_CHIP"
if [ ! -x "$ESP_IDF_DIR/install.sh" ]; then
    die "ESP-IDF install script not found at $ESP_IDF_DIR/install.sh"
fi
"$ESP_IDF_DIR/install.sh" "$TARGET_CHIP"

step "Verifying toolchain"
# shellcheck disable=SC1091
source "$ESP_IDF_DIR/export.sh" >/dev/null

zig_ok="no"
if command -v zig >/dev/null 2>&1; then
    info "zig:    $(zig version)"
    zig_ok="yes"
fi

idf_ok="no"
if command -v idf.py >/dev/null 2>&1; then
    info "idf.py: $(idf.py --version 2>&1 | tail -1)"
    idf_ok="yes"
fi

if [ "$zig_ok" = "no" ] || [ "$idf_ok" = "no" ]; then
    die "Verification failed. See errors above."
fi

step "Done"
cat <<EOF

${BOLD}Add this to your ~/.zshrc so every new shell can source ESP-IDF:${RESET}

    ${GREEN}alias get_idf='. $ESP_IDF_DIR/export.sh'${RESET}

Then, in any shell where you want to build the firmware:

    ${GREEN}get_idf${RESET}
    ${GREEN}cd firmware && idf.py set-target esp32c6 && idf.py build${RESET}

Host Zig tests do not need ESP-IDF:

    ${GREEN}cd firmware/zig && zig build test${RESET}

${DIM}Note: this script did not modify your shell rc — do that yourself.${RESET}
EOF
