pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Choices made from the bar itself (e.g. middle-clicking a status button),
// kept in ~/.local/state/quickbar/settings.json across restarts.
Singleton {
    id: root

    // The status buttons' details: the network's name, how many Bluetooth
    // devices are connected, the sound output and its level
    property alias showStatusDetails: adapter.showStatusDetails

    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickbar/settings.json"
        watchChanges: true
        onFileChanged: reload()
        // Saved as soon as a setting changes; the first save makes the file
        onAdapterUpdated: writeAdapter()
        printErrors: false

        JsonAdapter {
            id: adapter

            property bool showStatusDetails: false
        }
    }
}
