pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Choices made from the bar itself (e.g. middle-clicking the sound button),
// kept in ~/.local/state/quickbar/settings.json across restarts.
Singleton {
    id: root

    // The output's name beside the volume
    property alias showSinkName: adapter.showSinkName

    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickbar/settings.json"
        watchChanges: true
        onFileChanged: reload()
        // Saved as soon as a setting changes; the first save makes the file
        onAdapterUpdated: writeAdapter()
        printErrors: false

        JsonAdapter {
            id: adapter

            property bool showSinkName: false
        }
    }
}
