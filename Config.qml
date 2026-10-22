pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Choices made by hand in ~/.config/quickbar/config.json, which the bar only
// reads; edits apply as soon as the file is saved. Unlike Settings, nothing
// here is written back.
Singleton {
    id: root

    // Phone apps whose icon is illegible at chip size, as package → icon
    // shown on their Live Update chip instead: a name from icons/ or the
    // path to an image (e.g. a Papirus symbolic icon), tinted either way
    property alias liveIcons: adapter.liveIcons

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/quickbar/config.json"
        watchChanges: true
        onFileChanged: reload()
        printErrors: false

        JsonAdapter {
            id: adapter

            property var liveIcons: ({})
        }
    }
}
