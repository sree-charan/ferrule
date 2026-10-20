#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Sree Charan

# Copies Recast's converter, as Tools/build-recast.sh leaves it, into a Ferrule
# bundle so Convert needs nothing else installed:
#   Tools/embed-recast.sh <converter folder> <Ferrule.app>
# Signing is build.sh's job.
set -euo pipefail

source_dir="${1:?converter folder}"
target_app="${2:?Ferrule.app}"
dest="$target_app/Contents/Resources/Recast"

[[ -x "$source_dir/recast-cli" ]] || { echo "embed-recast: $source_dir has no recast-cli" >&2; exit 1; }
[[ -x "$source_dir/engines/7zip/7zz" && -x "$source_dir/engines/rhwp/rhwp" ]] || {
    echo "embed-recast: $source_dir is missing its engines" >&2
    exit 1
}
command rm -rf "$dest"
mkdir -p "$(dirname "$dest")"
/usr/bin/ditto "$source_dir" "$dest"
echo "  embedded Recast $("$dest/recast-cli" version 2>/dev/null | awk '{print $2}') ($(du -sh "$dest" | awk '{print $1}'))"
