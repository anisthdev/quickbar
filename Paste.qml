pragma Singleton

import Quickshell
import QtQuick

// Copying a pick to the clipboard and pasting it where the user was typing,
// for the clipboard and glyph menus. capture() notes the focused window when
// a menu opens; copy() then sets the clipboard and, unless told not to,
// sends that window its paste key once the menu has gone: Ctrl+Shift+V in a
// terminal, Ctrl+V elsewhere. The key goes by Hyprland's send_shortcut to
// that window's address, so it can't land anywhere else.
Singleton {
    id: root

    property string target: ""
    property bool terminal: false

    function capture() {
        target = HyprState.activeAddress;
        terminal = /ghostty|foot|kitty|alacritty|wezterm|term/i.test(HyprState.activeClass);
    }

    // { text } or { file } (an image)
    function copy(what, andPaste) {
        if (what.file)
            Quickshell.execDetached(["sh", "-c", 'wl-copy < "$1"', "copy", what.file]);
        else
            Quickshell.execDetached(["wl-copy", "--", what.text]);
        if (andPaste && target !== "")
            paste.restart();
    }

    // Once the menu has gone and the clipboard holds the pick
    property Timer paste: Timer {
        interval: 300
        onTriggered: {
            const mods = root.terminal ? "CTRL SHIFT" : "CTRL";
            Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.send_shortcut({ mods = "${mods}", key = "V", window = "address:${root.target}" })`]);
        }
    }
}
