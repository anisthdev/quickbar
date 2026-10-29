# File chooser: quickbar in the GTK portal's place

Apps ask for files through xdg-desktop-portal, which hands the dialog to a
backend. quickbar's backend is `scripts/filechooser-portal`, a small D-Bus
service (`org.freedesktop.impl.portal.desktop.quickbar`) that implements
`org.freedesktop.impl.portal.FileChooser`. It doesn't draw anything: each
call becomes a request over `$XDG_RUNTIME_DIR/quickbar/filechooser.sock` to
the shell, and `modules/FileChooser.qml` shows it as one of the menus.
The script's docstring describes the protocol.

```
app ─D-Bus→ xdg-desktop-portal ─D-Bus→ filechooser-portal ─socket→ FileChooser.qml
```

Every other portal (screenshots, screencasts, settings) stays with Hyprland's
and GTK's.

## Setup

`portal/install` sets it up and asks for sudo once:

- `portal/quickbar-portal.service` is linked into `~/.config/systemd/user`.
- `portal/org.freedesktop.impl.portal.desktop.quickbar.service` is linked
  into `~/.local/share/dbus-1/services`, so the first request starts the
  service.
- `portal/quickbar.portal` is copied to
  `/usr/share/xdg-desktop-portal/portals`. xdg-desktop-portal only reads it
  from there.
- In `~/.config/xdg-desktop-portal/hyprland-portals.conf`, it sets
  `org.freedesktop.impl.portal.FileChooser=quickbar`.

To go back to GTK's chooser, set that line back to `gtk` and run
`systemctl --user restart xdg-desktop-portal`.

## Which apps use it

Only apps that ask through the portal:

- Flatpaks, Chromium and Electron apps use it by default.
- Firefox needs `widget.use-xdg-desktop-portal.file-picker = 1` in
  about:config.
- Qt apps need `QT_QPA_PLATFORMTHEME=xdgdesktopportal`, or a platform theme
  that uses the portal.
- GTK apps need `GTK_USE_PORTAL=1` (GTK 3) or `GDK_DEBUG=portals` (GTK 4).

## Trying it

`scripts/filechooser-portal test open|multiple|folder|save|images` sends a
request straight to the shell, without D-Bus, and prints the answer.

## Not done yet

- `choices`: the extra combo boxes some apps add, such as an encoding picker.
  They're ignored, and apps get their defaults.
- `parent_window`: ignored. The chooser is an overlay on the focused monitor.
- A mime type filter only matches the globs registered for that exact type
  (or for a whole kind, like `image/*`), not its subclasses.
