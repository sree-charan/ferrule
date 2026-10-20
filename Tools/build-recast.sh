#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Sree Charan

# Builds Recast's command line converter from the source in Recast/ and adds
# the engines it ships with, ready for Tools/embed-recast.sh:
#   Tools/build-recast.sh <output folder>
#
# Needs the .NET SDK that Recast/global.json names. When none is installed it
# is installed for this user under ~/.dotnet with Microsoft's install script.
# The engines (rhwp, 7-Zip) are the downloads Recast pins in engines.json; each
# is checked against its SHA-256 and kept in ~/Library/Caches so a rebuild
# needs no network.
set -euo pipefail
cd "$(dirname "$0")/.."

output="${1:?output folder}"
recast="Recast"
runtime="osx-$(uname -m | sed 's/x86_64/x64/')"
cache="$HOME/Library/Caches/com.sreecharan.ferrule.build"
[[ -f "$recast/Recast.slnx" ]] || { echo "build-recast: no Recast source in $recast/" >&2; exit 1; }

# ── .NET SDK ──
sdk_channel="$(/usr/bin/python3 -c 'import json,sys; v=json.load(open(sys.argv[1]))["sdk"]["version"]; print(".".join(v.split(".")[:2]))' "$recast/global.json")"
dotnet_bin=""
for candidate in "$(command -v dotnet 2>/dev/null || true)" "$HOME/.dotnet/dotnet" /usr/local/share/dotnet/dotnet; do
    [[ -n "$candidate" && -x "$candidate" ]] || continue
    if "$candidate" --list-sdks 2>/dev/null | grep -q "^$sdk_channel\."; then
        dotnet_bin="$candidate"
        break
    fi
done
if [[ -z "$dotnet_bin" ]]; then
    echo "  installing the .NET $sdk_channel SDK into ~/.dotnet (one time, about 250 MB)…"
    mkdir -p "$cache"
    /usr/bin/curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$cache/dotnet-install.sh"
    /bin/bash "$cache/dotnet-install.sh" --channel "$sdk_channel" --install-dir "$HOME/.dotnet" >/dev/null
    dotnet_bin="$HOME/.dotnet/dotnet"
fi
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1

# ── The converter ──
command rm -rf "$output"
"$dotnet_bin" publish "$recast/src/Recast.Cli/Recast.Cli.csproj" -c Release -r "$runtime" --self-contained true \
    -p:RecastRelease=true -o "$output" -v quiet -nologo >"$cache.publish.log" 2>&1 || {
    tail -30 "$cache.publish.log" >&2
    echo "build-recast: dotnet publish failed (full log: $cache.publish.log)" >&2
    exit 1
}
[[ -x "$output/recast-cli" ]] || { echo "build-recast: publish made no recast-cli" >&2; exit 1; }

# ── Its engines ──
mkdir -p "$cache/engines"
/usr/bin/python3 - "$recast/src/Recast.Engines/Infrastructure/engines.json" "$runtime" "$cache/engines" "$output/engines" <<'PY'
import hashlib, json, os, shutil, subprocess, sys, tarfile, tempfile, urllib.request
manifest, runtime, cache, dest = sys.argv[1:]
components = json.load(open(manifest))["platforms"][runtime]["components"]
os.makedirs(dest, exist_ok=True)
for name, executable in (("rhwp", "rhwp"), ("7zip", "7zz")):
    c = components[name]
    archive = os.path.join(cache, f"{c['sha256']}.{c['kind']}")
    def digest(path):
        h = hashlib.sha256()
        with open(path, "rb") as f:
            for block in iter(lambda: f.read(1 << 20), b""):
                h.update(block)
        return h.hexdigest().upper()
    if not os.path.exists(archive) or digest(archive) != c["sha256"].upper():
        partial = archive + ".partial"
        print(f"  downloading {name}…", flush=True)
        urllib.request.urlretrieve(c["url"], partial)
        if digest(partial) != c["sha256"].upper():
            os.remove(partial)
            sys.exit(f"build-recast: checksum mismatch for {name}")
        os.replace(partial, archive)
    with tarfile.open(archive) as tar:
        for member in tar.getmembers():
            if member.name.startswith(("/", "\\")) or ".." in member.name.replace("\\", "/").split("/") \
                    or not (member.isfile() or member.isdir()):
                sys.exit(f"build-recast: unsafe entry {member.name!r} in {name}")
        stage = tempfile.mkdtemp(dir=cache)
        tar.extractall(stage)
    children = os.listdir(stage)
    payload = os.path.join(stage, children[0]) if len(children) == 1 and os.path.isdir(os.path.join(stage, children[0])) else stage
    if not os.path.isfile(os.path.join(payload, executable)):
        sys.exit(f"build-recast: {executable} missing from {name}")
    target = os.path.join(dest, name)
    shutil.rmtree(target, ignore_errors=True)
    shutil.move(payload, target)
    os.chmod(os.path.join(target, executable), 0o755)
    shutil.rmtree(stage, ignore_errors=True)
PY

cp "$recast/LICENSE" "$output/LICENSE"
cp "$recast/THIRD-PARTY-NOTICES.md" "$output/THIRD-PARTY-NOTICES.md"
echo "  built Recast $("$output/recast-cli" version | awk '{print $2}') for $runtime"
