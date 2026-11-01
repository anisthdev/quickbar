import Quickshell
import QtQuick
import ".."
import "../components"

// mpd's now playing chip: album art, the title and a little equalizer while
// it plays; hidden when stopped. Click for the music menu (its foot is the
// player), middle-click to play/pause. The player itself is MpdPlayer.
Pill {
    id: root

    readonly property var player: MpdPlayer

    padding: 8
    spacing: 8
    visible: player.active
    clickable: true
    onClicked: event => {
        if (event.button === Qt.MiddleButton)
            player.mpc("toggle");
        else
            Panels.musicMenu?.toggle();
    }

    AlbumArt {
        anchors.verticalCenter: parent.verticalCenter
        size: 20
        source: root.player.art
    }

    Label {
        width: Math.min(implicitWidth, 180)
        text: root.player.title
        elide: Text.ElideRight
        opacity: root.player.playing ? 1 : 0.6

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animNormal
            }
        }
    }

    Equalizer {
        playing: root.player.playing
        color: Theme.primary
    }

    // `qs -p <dir> ipc call media toggle` (Super+Alt+M), through BarIpc:
    // the music menu, once, from the bar on the focused monitor
    Connections {
        target: BarIpc
        function onToggled(name, monitor) {
            if (name === "media" && monitor === root.QsWindow.window?.screen?.name)
                Panels.musicMenu?.toggle();
        }
    }
}
