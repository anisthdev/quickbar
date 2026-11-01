# Screen sharing: quickbar's picker in xdph's

When an app starts a screen share, xdg-desktop-portal-hyprland (xdph) runs
a picker program and reads the choice from its output. xdph still does the
sharing itself (PipeWire and the restore tokens); quickbar only asks what
to share.

`~/.config/hypr/xdph.conf` sets the picker:

```
screencopy {
    custom_picker_binary = /usr/lib/quickbar/share-picker
}
```

`scripts/share-picker` passes xdph's window list to the shell over
`$XDG_RUNTIME_DIR/quickbar/sharepicker.sock`. `modules/SharePicker.qml`
asks the question and returns the choice: a screen, a window, or a region
picked with the region selector. The script's docstring describes the
protocol.

If quickbar isn't running, the script starts hyprland-share-picker instead.
xdph reads its config only at startup, so after changing the picker run
`systemctl --user restart xdg-desktop-portal-hyprland`.

## Trying it

<https://mozilla.github.io/webrtc-landing/gum_test.html> with "Screen
capture", or any video call.
