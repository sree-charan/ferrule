#!/bin/sh
set -eu

data_dir=${XDG_DATA_HOME:-"$HOME/.local/share"}
install_dir="$data_dir/recast/application"
desktop_file="$data_dir/applications/io.github.sree-charan.recast.desktop"
python3 - "$data_dir" "$install_dir" <<'PY'
import pathlib
import sys

root, target = map(pathlib.Path, sys.argv[1:])
expected = root.resolve() / 'recast' / 'application'
if target.is_symlink() or target.resolve() != expected:
    raise SystemExit('Refusing to remove an installation outside its expected directory.')
if (target / '.recast-package').read_text(encoding='utf-8').strip() != 'io.github.sree-charan.recast':
    raise SystemExit('The directory is not an installation created by Recast.')
PY
"$install_dir/Recast" --uninstall-cleanup
if [ -L "$HOME/.local/bin/recast" ] && [ "$(readlink "$HOME/.local/bin/recast")" = "$install_dir/recast-cli" ]; then
    rm -- "$HOME/.local/bin/recast"
fi
if [ -f "$desktop_file" ] && grep -q '^X-Recast-Managed=true$' "$desktop_file"; then
    rm -- "$desktop_file"
fi
rm -rf -- "$install_dir"
printf '%s\n' 'Recast was removed. Your settings and conversion results were kept.'
