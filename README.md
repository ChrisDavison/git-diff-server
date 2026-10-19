# git-diff-server

A small local web server for scrubbing through one file's git history as a
side-by-side diff. Pick a repository, pick a file (including files that have
since been deleted), then drag the **L** and **R** handles along the commits
that touched it.

Python 3.8+ standard library only; no build step.

## Install as a service

```sh
./install.sh
```

This links `git-diff-server` into `~/.local/bin/`, then registers it as a
background service that starts at login and restarts if it crashes: a launchd
agent on macOS, a systemd user unit on Linux. The server listens on
<http://localhost:7465/>. Re-run it after pulling changes.

```sh
./install.sh --uninstall    # stop and remove the service and the link
./install.sh --no-service   # only link the script onto PATH
```

On other systems, or without a systemd user session, `install.sh` only links
the script; run `git-diff-server serve` under whatever supervisor you use.

### macOS (launchd)

`install.sh` writes `~/Library/LaunchAgents/local.git-diff-server.plist`.
launchd starts agents with a bare `PATH`, so the plist pins the `python3` and
`git` that were on your `PATH` at install time. Re-run `install.sh` if you
change either.

```sh
launchctl print gui/$(id -u)/local.git-diff-server     # status
tail -f ~/Library/Logs/git-diff-server.log             # logs
launchctl kickstart -k gui/$(id -u)/local.git-diff-server   # restart
```

Repositories under `~/Documents`, `~/Desktop` or `~/Downloads` are protected
by macOS privacy controls. The background service can't read them until you
grant your `python3` access in System Settings › Privacy & Security ›
Files and Folders (or Full Disk Access).

### Linux (systemd)

```sh
systemctl --user status git-diff-server
journalctl --user -u git-diff-server -f
```

## Run manually

```sh
./git-diff-server serve               # serve on http://localhost:7465/
./git-diff-server serve --port 8000   # another port
```

## Open a file from the terminal

```sh
git-diff-server open path/to/file     # jump straight to a file's history
git-diff-server open                  # current repository, no file selected
```

`open` uses the running server if there is one on the port (default 7465).
Otherwise it starts a server in the foreground until Ctrl-C, so it also works
without the service.

## Using the page

- **Repository**: the 📁 button opens a directory browser. Folders that are git
  repositories are badged; recent repositories are listed underneath. Any path
  you can read is allowed; type one and press Enter.
- **Files**: the sidebar lists files tracked at `HEAD`. The filter takes plain
  text (substring) or globs (`*.py`, `bin/**`). Tick **Include deleted files**
  to also list paths deleted in `HEAD`'s history. Binary files and submodules
  are greyed out.
- **Timeline**: one bar per commit that touched the file (following renames),
  height scaled by lines changed. A hatched bar at the end is uncommitted
  working-tree changes. For a deleted file the timeline ends at its last
  version.
- **Scrubbing**: drag a handle or click a bar (the nearer handle moves;
  shift-click moves L). `←`/`→` move R, `Shift+←`/`Shift+→` move L.
  **Lock gap** moves both together.
- **Diff**: unchanged runs collapse to 3 lines of context; click to expand.
  The change list in the sidebar jumps to each change. **Word diff** marks the
  changed words within a line. **Syntax highlight** uses highlight.js,
  downloaded once into `~/.cache/git-diff-server/`.

The repository, file and both commits are kept in the URL, so refresh, back and
bookmarks work.

## Files

| Path | Purpose |
| --- | --- |
| `git-diff-server` | server and CLI |
| `static/index.html` | the page |
| `git-diff-server.service` | systemd user unit |
| `install.sh` | links the script, installs the launchd agent or systemd unit |

State lives in `~/.local/state/git-diff-server/recent.json`.
