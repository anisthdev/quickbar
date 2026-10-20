//@ pragma UseQApplication
//@ pragma IconTheme Papirus-Dark

import Quickshell
import Quickshell.Io
import QtQuick
import "modules"

ShellRoot {
    id: root

    // Super+Shift+Space hides the bar (and its room) and brings it back
    property bool barShown: true

    IpcHandler {
        target: "bar"

        function toggle(): void {
            root.barShown = !root.barShown;
        }
    }

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
            visible: root.barShown
            apps: appLauncher
        }
    }

    Notifications {}
    MediaSearch {
        id: mediaSearch
    }

    Games {
        id: games
    }

    Entertainment {
        search: mediaSearch
        games: games
    }

    AppLauncher {
        id: appLauncher
    }

    PowerMenu {
        id: power
    }

    Capture {
        id: capture
    }

    WallpaperPicker {
        id: wallpaper
    }

    QuickNote {}

    Keybindings {}

    Clipboard {}

    ControlPanel {
        power: power
        capture: capture
        wallpaper: wallpaper
    }
}
