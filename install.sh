#!/usr/bin/env bash
# Link the script onto PATH and run it as a systemd user service. Safe to re-run.
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
unit=git-diff-server.service

mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"
ln -sfn "$repo/git-diff-server" "$HOME/.local/bin/git-diff-server"
ln -sfn "$repo/$unit" "$HOME/.config/systemd/user/$unit"

systemctl --user daemon-reload
systemctl --user enable "$unit"
systemctl --user restart "$unit"
systemctl --user --no-pager status "$unit" | head -n 3
