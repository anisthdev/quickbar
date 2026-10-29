# Downloads: how apps show progress in the bar

The bar's downloads pill (a ring with the newest download's progress) and
its dropdown (every download, with its app's badge) show downloads from
anything: Transmission, quickbar's own scripts, apps built later, and other
people's apps. `DownloadHub` (a singleton, in place of `DownloadState`) keeps
them in one list. This is the contract between it and whatever downloads.

Downloads only, for now: no copies, encodes or builds.

## A download

```js
{
  app:      "tunes",            // who it belongs to: a desktop entry id where
                                // there is one (its icon and name are the
                                // badge), else any name
  id:       "a1",               // unique within the app
  title:    "Abbey Road",
  subtitle: "The Beatles",      // optional
  progress: 0.42,               // 0–1, or null while it can't tell (a spinner)
  state:    "downloading",      // queued | downloading | paused | processing | error
  detail:   "3 of 17 · Tagging",// optional; else made from rate, eta, item
  rate:     1200000,            // optional, bytes a second
  eta:      95,                 // optional, seconds
  item:     { index: 3, total: 17 }, // optional, for downloads of several things
  error:    "",                 // why, when state is error
  actions:  ["pause", "cancel"],// buttons the dropdown offers: pause, resume,
                                // cancel, dismiss
  open:     ["~/Projects/seedling/seedling", "show", "42"],
                                // optional: what a click on its row runs (argv,
                                // ~ expanded); else its app's desktop entry
                                // is launched, if it has one
  icon:     "",                 // optional: a badge for apps without a
  appName:  ""                  // desktop entry (icon name or path, name)
}
```

A finished download is gone from the list: the pill shows it for a moment,
full, with a check (as now). One that failed stays, with its error, until
dismissed or retried.

## Ways in

### 1. The socket (apps)

`$XDG_RUNTIME_DIR/quickbar/downloads.sock`, a Unix socket served by the shell
itself (Quickshell's `SocketServer`), only reachable by the user. Messages
are one JSON object a line, both ways.

From the app:

```
{"op":"update","app":"tunes","id":"a1","title":"Abbey Road","progress":0.42,"actions":["pause","cancel"]}
{"op":"update","app":"tunes","id":"a1","progress":0.43}     fields merge into what's there
{"op":"done","app":"tunes","id":"a1"}                        finished: shown for a moment, then gone
{"op":"fail","app":"tunes","id":"a1","error":"No space left"}
{"op":"remove","app":"tunes","id":"a1"}                      gone without a word (cancelled)
{"op":"poke","provider":"transmission"}                      look now (see Providers)
```

From the hub, on the same connection, when a button is pressed:

```
{"op":"action","app":"tunes","id":"a1","action":"pause"}
```

The app does it and sends the new state; the hub assumes nothing.

A download belongs to the connection that last updated it. When the
connection closes, its unfinished downloads turn into errors ("Stopped
unexpectedly"), so a crashed app doesn't leave a ring spinning for ever. An
app that reconnects (say, after the shell restarted) sends its downloads
again.

### 2. The `download` command (scripts)

`scripts/download`, in place of today's runner, for anything that's a shell
command away:

```
download start [--app A] [--title T] [--subtitle S] [--total N] [--open CMD]
               [--cwd DIR] [--scratch DIR] [--done SHELL] -- CMD...
download update|done|fail|remove --app A --id ID [--title T] [--progress P] …
download poke transmission
```

`start` is today's runner, unchanged for the caller (tunes, the media
search): it runs CMD detached and reads `@progress`, `@item`, `@rate`,
`@eta`, `@size`, `@status`, `@error` lines from it, as now. What changes is
behind it: instead of writing job files for the bar to poll, it stays
connected to the socket while CMD runs and sends updates as they come. It
does the dropdown's actions itself: pause stops CMD, resume starts it again
(it should pick up where it was; yt-dlp does), cancel stops it and removes
`--scratch`. `--done` runs once CMD succeeds, as "processing".

`update` and the rest are one message each, for scripts that report as they
go without staying connected. Those downloads aren't tied to a connection;
they're dropped if not updated for a minute.

### 3. Providers (daemons with their own state)

Downloads that live in a daemon are read from it by the hub, not pushed:
Transmission's unfinished torrents, from its RPC. A provider polls slowly
(10 s) when nothing is downloading, every 1.5 s while something is or the
dropdown is open, and every half second for a moment after a `poke`. The
media search pokes after adding a torrent, so it shows up at once.

Transmission's downloads have `app` Seedling's desktop entry id
(`io.github.anisthdev.Seedling`), and a click opens Seedling on that
torrent's details (`~/Projects/seedling/seedling show <id>`, which starts
Seedling if need be). Pause and resume are done by the provider (RPC).

### 4. Bridges (other people's apps)

- **Progress notifications.** A notification with a number in its `value`
  hint (0–100), as `notify-send -h int:value:42 …` and some apps send, is a
  download instead of a popup: its app from the `desktop-entry` hint or the
  app name, its title from the summary, its id the notification's; × in the
  dropdown dismisses the notification. It's gone when the notification
  closes (finished, if it got to 100). Left as popups: levels (volume,
  brightness: a value with `x-canonical-private-synchronous`, as sysaud and
  `brightness` send), a value that isn't a
  number (`busy`'s spinner, `value:busy`), a notification replacing a popup
  on screen (`busy`'s "Done"), and a download whose replacement has no
  value any more (a final message) leaves the pill for a popup.

Browsers are left out: they show their own downloads. (Neither sends Unity
LauncherEntry progress under Hyprland, checked with `busctl --user monitor`
during a Chrome download; a browser extension talking to the socket would
be the way, should it ever be wanted.)

## The bar

- The pill: the newest download's ring and percentage; a small count when
  there's more than one. Hidden when there's nothing.
- The dropdown (click, or SUPER+ALT+D): every download, newest first, each
  with its app's badge (desktop entry icon, else `icon`), title, progress,
  detail and its `actions` as buttons. A click on a row runs its `open`
  (else launches its app). Keys: j/k, Space or p pauses or resumes, x
  cancels or dismisses, Enter or l opens.

## Where it stands

Built: `DownloadHub` (the list, the socket, the Transmission provider,
`poke`), `scripts/download` on the socket, the dropdown's badges, actions and
click to open, Seedling's `seedling show <id>`, and the notification bridge.
tunes passes `--app tunes --app-name Music --icon multimedia-audio-player
--open "qs -p ~/Projects/quickbar ipc call musicmenu open"`; older callers'
`--kind` still works. The media search pokes Transmission after adding a
torrent.
