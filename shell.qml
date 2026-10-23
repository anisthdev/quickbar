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
            // Not over the boot logo before the lock screen is up
            visible: root.barShown && !lockScreen.booting
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

    RegionSelector {
        id: region
    }

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
        id: lockScreen
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
        region: region
        wallpaper: wallpaper
        keepAwake: keepAwake
        keyboard: keyboard
    }
}
