#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Sree Charan

# Installs Ferrule from source in one line:
#   curl -fsSL https://raw.githubusercontent.com/sree-charan/ferrule/main/install.sh | zsh
#
# Keeps the source in ~/.ferrule, builds the app and its file converter there
# and installs Ferrule.app into /Applications. Run it again to update.
set -euo pipefail

repository="https://github.com/sree-charan/ferrule.git"
source_dir="${FERRULE_SOURCE:-$HOME/.ferrule}"

say() { print -P "%B▸%b $1"; }
fail() { print -u2 "✗ $1"; exit 1; }

[[ "$(uname -s)" == Darwin ]] || fail "Ferrule runs on macOS."
[[ "$(uname -m)" == arm64 ]] || fail "Ferrule needs a Mac with Apple Silicon."
macos_major="$(sw_vers -productVersion | cut -d. -f1)"
(( macos_major >= 14 )) || fail "Ferrule needs macOS 14 or newer (this Mac has $(sw_vers -productVersion))."

if ! xcode-select -p >/dev/null 2>&1 || ! xcrun --find swiftc >/dev/null 2>&1; then
    say "Installing the Xcode Command Line Tools. Finish the dialog, then run this command again."
    xcode-select --install 2>/dev/null || true
    exit 1
fi

if [[ -d "$source_dir/.git" ]]; then
    say "Updating the source in $source_dir…"
    git -C "$source_dir" pull --ff-only --quiet
else
    say "Downloading the source into $source_dir…"
    git clone --depth 1 --quiet "$repository" "$source_dir"
fi

say "Building and installing Ferrule (the first build takes a few minutes)…"
cd "$source_dir"
./build.sh --install

open /Applications/Ferrule.app
say "Ferrule is installed. Its icon is in the menu bar."
