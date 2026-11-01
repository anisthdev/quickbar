# Protocols: how other programs talk to quickbar, and what it reads

quickbar is the shell; everything else runs on its own and meets it only
through the channels below. Each is either a freedesktop standard, a
command on PATH, or a file whose format is written down here or by the
program that writes it. Nothing here names a source checkout or another
program's private files, and every one of them may be missing: the part
of the bar that uses it hides or falls back.

## What quickbar offers

### IPC: `qs -c quickbar ipc call TARGET FUNCTION [ARGS]`

Quickshell's IPC to the running shell. `qs -c quickbar ipc show` lists every
target and function. The ones other programs use:

| Call | From |
|---|---|
| `lock lock` | hypridle's `lock_cmd`; `lock isLocked` from `scripts/boot` |
| `launcher toggle`, `clipboard toggle`, `controlpanel toggle`, … | Hyprland's keybinds |

### Sockets: `$XDG_RUNTIME_DIR/quickbar/*.sock`

One JSON object a line, both ways, served by the shell itself.

- `downloads.sock`: downloads in the bar's pill. [downloads.md](downloads.md)
  has the protocol; `quickbar-download` (on PATH) is the client for
  scripts, and tunes uses it when it's there.
- `filechooser.sock`: the file chooser portal's dialogs.
  [filechooser.md](filechooser.md).
- `sharepicker.sock`: xdph's screen-share picker.
  [screenshare.md](screenshare.md).

### D-Bus

The shell serves `org.freedesktop.Notifications`, the
`org.kde.StatusNotifierWatcher` tray host, the polkit agent, and (through
`/usr/lib/quickbar/filechooser-portal`) the portal backend
`org.freedesktop.impl.portal.desktop.quickbar` for FileChooser.

### Notification hints

Anything that sends notifications already works. These hints change how
the bar shows them:

| Hint | Shown as |
|---|---|
| `value` (int 0–100) | A download in the pill, not a popup ([downloads.md](downloads.md), Bridges). Replacing it with a notification without `value` turns it into a popup (a final "Done"). |
| `value` with `x-canonical-private-synchronous` (string, a kind such as `brightness`) | A level (volume, brightness): one popup per kind, replaced in place with a thick bar. sysaud and `brightness` send these. |
| `value` negative or not a number (`-h string:value:busy`) | A popup with a travelling wave: busy, with no known end. `busy` sends these. |
| `x-kde-reply-placeholder-text` with an `inline-reply` action | A reply field (KDE's inline reply, answered with `NotificationReplied`). handoff uses it. |
| `desktop-entry` | The app's name and icon on the card and the download's badge. |

### Meters: `$XDG_CACHE_HOME/quickbar/meters/SOURCE.json`

A ring in the bar for anything that's used up or done. Any program writes
the file, the bar watches it:

```json
{"items": [{"label": "5-hour", "progress": 0.23, "text": "23% used",
            "resets_at": 1793600000, "reset_progress": 0}],
 "pids": [1234]}
```

`progress` is 0–1; `text`, `resets_at` (epoch seconds, after which the item
counts as `reset_progress`) and `pids` (shown only while one runs) are
optional. `/usr/lib/quickbar/claude-usage` writes `claude.json`.

## What quickbar reads

| What | From | How |
|---|---|---|
| The palette | matugen | `$XDG_CONFIG_HOME/quickbar/colors.css`, `@define-color NAME rgba(…)` lines, watched |
| Its settings | you | `$XDG_CONFIG_HOME/quickbar/config.json` (`Config.qml` documents the keys), `calendars`, `jackett` |
| The weather | weather | `weather --forecast` on PATH, JSON |
| Music search and downloads | tunes | `tunes search\|tracks --json`, `tunes get` on PATH |
| Torrents | transmission-daemon | its RPC at `127.0.0.1:9091`; a row's click runs `seedling show ID` |
| Searching torrents | Jackett | its Torznab API, key and URL in `$XDG_CONFIG_HOME/quickbar/jackett` |
| The video library | reel | `reel-scan` on PATH; `$XDG_CACHE_HOME/reel/library.json` (reel's README has the format) |
| Playback progress | mpv | `$XDG_STATE_HOME/mpv/watch_later/` and `watch_history.jsonl`, mpv's documented files; marking a video watched removes its resume file |
| The phone's Live Updates | handoff | `$XDG_RUNTIME_DIR/handoff/live.json` (handoff's README has the format) |
| The clipboard history | clipse | `$XDG_CONFIG_HOME/clipse/clipboard_history.json`, read only; pins are quickbar's own |
| Music | mpd | `mpc` |
| Workspaces, windows, binds | Hyprland | Quickshell's Hyprland module and `hyprctl -j` |
| The wallpaper | awww, matugen | `awww query`; the wallpaper picker runs `matugen image` |
| Commands of yours | you | `toggle-handoff`, `toggle-nightlight`, `battery-limit` on PATH (the control panel's switches); `phoneMirror` in config.json |
