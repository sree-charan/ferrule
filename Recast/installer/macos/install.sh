#!/bin/sh
set -eu

source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
install_dir="$HOME/Applications/Recast.app"
bin_dir="$HOME/.local/bin"
if [ -e "$install_dir" ] || [ -L "$install_dir" ]; then
    printf '%s\n' "An installation already exists at $install_dir. Run uninstall.sh first."
    exit 1
fi
if [ -e "$bin_dir/recast" ] || [ -L "$bin_dir/recast" ]; then
    printf '%s\n' "$bin_dir/recast already exists. Remove or rename it before installing Recast."
    exit 1
fi
test -x "$source_dir/Recast.app/Contents/MacOS/Recast"
mkdir -p "$HOME/Applications" "$bin_dir"
/usr/bin/ditto "$source_dir/Recast.app" "$install_dir"
ln -s "$install_dir/Contents/MacOS/recast-cli" "$bin_dir/recast"
printf '%s\n' "Installed $install_dir" "CLI: $bin_dir/recast (add $bin_dir to PATH if needed)."
printf '%s\n' 'Open Recast from Applications. Grant Accessibility and Finder Automation access when requested.'
