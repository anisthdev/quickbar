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

    Reel {
        id: reel
    }

    ReelMenu {
        reel: reel
    }

    MusicMenu {
        id: musicMenu
    }

    Entertainment {
        search: mediaSearch
        games: games
        reel: reel
        music: musicMenu
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

    RegionSelector {}

    WallpaperPicker {
        id: wallpaper
    }

    QuickNote {}

    Calculator {}

    TasksMenu {}

    Keybindings {}

    Clipboard {}

    GlyphPicker {}

    EmojiPicker {}

    LockScreen {
        keepAwake: keepAwake
    }

    Polkit {}

    KeepAwake {
        id: keepAwake
    }

    Keyboard {
        id: keyboard
    }

    ControlPanel {
        power: power
        capture: capture
        wallpaper: wallpaper
        keepAwake: keepAwake
        keyboard: keyboard
    }
}
