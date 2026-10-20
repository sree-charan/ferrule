#!/bin/sh
set -eu

install_dir="$HOME/Applications/Recast.app"
if [ -L "$install_dir" ] || [ ! -d "$install_dir" ]; then
    printf '%s\n' "No ordinary Recast app bundle was found at $install_dir."
    exit 1
fi
resolved_parent=$(CDPATH= cd -- "$HOME/Applications" && pwd -P)
resolved_app=$(CDPATH= cd -- "$install_dir" && pwd -P)
if [ "$resolved_app" != "$resolved_parent/Recast.app" ]; then
    printf '%s\n' 'Refusing to remove an app outside the expected Applications directory.'
    exit 1
fi
bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$install_dir/Contents/Info.plist")
if [ "$bundle_id" != 'io.github.sree-charan.recast' ]; then
    printf '%s\n' 'The bundle is not Recast.'
    exit 1
fi
"$install_dir/Contents/MacOS/Recast" --uninstall-cleanup
if [ -L "$HOME/.local/bin/recast" ] && [ "$(readlink "$HOME/.local/bin/recast")" = "$install_dir/Contents/MacOS/recast-cli" ]; then
    rm -- "$HOME/.local/bin/recast"
fi
rm -rf -- "$install_dir"
printf '%s\n' 'Recast was removed. Your settings and conversion results were kept.'
