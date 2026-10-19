#!/usr/bin/env bash
# Link the script onto PATH and run it as a background user service: a launchd
# agent on macOS, a systemd user unit on Linux. Safe to re-run.
#
#   ./install.sh               install (or reinstall) and (re)start the service
#   ./install.sh --uninstall   stop and remove the service and the PATH link
#   ./install.sh --no-service  only link the script onto PATH
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
name=git-diff-server
port=7465
bin="$HOME/.local/bin/$name"

mode=install
case "${1:-}" in
    "") ;;
    --uninstall) mode=uninstall ;;
    --no-service) mode=link ;;
    *) echo "usage: $0 [--uninstall | --no-service]" >&2; exit 2 ;;
esac

# --- launchd (macOS) -------------------------------------------------------

label="local.$name"
plist="$HOME/Library/LaunchAgents/$label.plist"
domain="gui/$(id -u)"
log="$HOME/Library/Logs/$name.log"

launchd_install() {
    # launchd starts agents with a bare PATH (/usr/bin:/bin:...), so pin the
    # python3 and git found now; otherwise Homebrew's would be skipped.
    local python git
    python=$(command -v python3) || { echo "python3 not found" >&2; exit 1; }
    git=$(command -v git) || { echo "git not found" >&2; exit 1; }

    mkdir -p "$(dirname "$plist")" "$(dirname "$log")"
    cat >"$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$label</string>
    <key>ProgramArguments</key>
    <array>
        <string>$python</string>
        <string>$bin</string>
        <string>serve</string>
        <string>--port</string>
        <string>$port</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>$(dirname "$git"):/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>ProcessType</key>
    <string>Background</string>
    <key>StandardOutPath</key>
    <string>$log</string>
    <key>StandardErrorPath</key>
    <string>$log</string>
</dict>
</plist>
EOF
    plutil -lint -s "$plist"

    launchctl bootout "$domain/$label" 2>/dev/null || true
    launchctl enable "$domain/$label"
    launchctl bootstrap "$domain" "$plist"
    launchctl print "$domain/$label" | grep -m 2 -E '^\s*(state|pid) =' || true
    echo "Logs: $log"
}

launchd_uninstall() {
    launchctl bootout "$domain/$label" 2>/dev/null || true
    rm -f "$plist"
}

# --- systemd (Linux) -------------------------------------------------------

unit="$name.service"
unit_dir="$HOME/.config/systemd/user"

systemd_install() {
    mkdir -p "$unit_dir"
    ln -sfn "$repo/$unit" "$unit_dir/$unit"
    systemctl --user daemon-reload
    systemctl --user enable "$unit"
    systemctl --user restart "$unit"
    systemctl --user --no-pager status "$unit" | head -n 3
}

systemd_uninstall() {
    systemctl --user disable --now "$unit" 2>/dev/null || true
    rm -f "$unit_dir/$unit"
    systemctl --user daemon-reload
}

# ---------------------------------------------------------------------------

if [[ "$(uname -s)" == Darwin ]]; then
    manager=launchd
elif command -v systemctl >/dev/null && systemctl --user show-environment >/dev/null 2>&1; then
    manager=systemd
else
    manager=none
fi

if [[ $mode == uninstall ]]; then
    [[ $manager != none ]] && "${manager}_uninstall"
    rm -f "$bin"
    echo "Uninstalled."
    exit 0
fi

mkdir -p "$(dirname "$bin")"
ln -sfn "$repo/$name" "$bin"
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo "Note: ~/.local/bin is not on your PATH." ;; esac

if [[ $mode == link ]]; then
    exit 0
fi
if [[ $manager == none ]]; then
    echo "No launchd or systemd user session found; linked $bin only." >&2
    echo "Run '$name serve' under your own process supervisor." >&2
    exit 0
fi
"${manager}_install"
echo "Serving on http://localhost:$port/"
