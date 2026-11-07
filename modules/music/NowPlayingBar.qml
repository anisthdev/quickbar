import QtQuick
import "../.."
import "../../components"

// The music menu's foot: what mpd is playing (its cover, title and artist),
// previous, play/pause and next, shuffle and repeat, its lyrics, and how far
// along it is, a wavy line while it plays that seeks on a click. A click on
// the song asks for the queue (`opened`). Hidden while mpd is stopped.
Rectangle {
    id: root

    readonly property var player: MpdPlayer
    // The lyrics page is open
    property bool lyricsOpen: false

    signal opened
    signal lyrics

    function clock(seconds) {
        return `${Math.floor(seconds / 60)}:${String(Math.round(seconds) % 60).padStart(2, "0")}`;
    }

    height: 76
    radius: Theme.cardRadius
    color: Qt.alpha(Theme.surface_container_high, Theme.alpha)

    // The song: a click opens the queue
    Item {
        id: song

        anchors.left: parent.left
        anchors.right: controls.left
        anchors.rightMargin: 12
        height: parent.height - progress.height - 6

        AlbumArt {
            id: art

            x: 12
            anchors.verticalCenter: parent.verticalCenter
            size: 44
            source: root.player.art
        }

        Column {
            anchors.left: art.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Label {
                anchors.verticalCenter: undefined
                width: parent.width
                text: root.player.title
                color: Theme.on_surface
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Label {
                anchors.verticalCenter: undefined
                width: parent.width
                text: [root.player.artist, root.player.album].filter(s => s).join("  ·  ")
                color: Theme.on_surface_variant
                font.pixelSize: 12
                font.weight: Font.Normal
                elide: Text.ElideRight
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.opened()
        }
    }

    Row {
        id: controls

        anchors.right: parent.right
        anchors.rightMargin: 12
        y: (song.height - height) / 2
        spacing: 4

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "lyrics"
            iconSize: 16
            color: root.lyricsOpen ? Theme.primary : Theme.on_surface_variant
            onClicked: root.lyrics()
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "media_shuffle"
            iconSize: 16
            color: root.player.random ? Theme.primary : Theme.on_surface_variant
            onClicked: root.player.mpc("random")
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "media_skip_previous"
            iconSize: 20
            color: Theme.on_surface
            onClicked: root.player.mpc("prev")
        }

        // Round while paused, a rounded square while playing
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 42
            height: 42
            radius: root.player.playing ? 13 : 21
            color: playMouse.containsMouse ? Qt.lighter(Theme.primary, 1.08) : Theme.primary
            scale: playMouse.pressed ? 0.94 : 1

            Behavior on radius {
                NumberAnimation {
                    duration: 350
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.5
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Theme.animFast
                }
            }

            Icon {
                anchors.centerIn: parent
                name: root.player.playing ? "media_pause" : "media_play_arrow"
                size: 22
                color: Theme.on_primary
            }

            MouseArea {
                id: playMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.player.mpc("toggle")
            }
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "media_skip_next"
            iconSize: 20
            color: Theme.on_surface
            onClicked: root.player.mpc("next")
        }

        // Repeat, then repeat one, then off
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: root.player.repeat && root.player.single ? "media_repeat_one" : "media_repeat"
            iconSize: 16
            color: root.player.repeat ? Theme.primary : Theme.on_surface_variant
            onClicked: {
                if (!root.player.repeat)
                    root.player.mpc("repeat", "on");
                else if (!root.player.single)
                    root.player.mpc("single", "on");
                else {
                    root.player.mpc("repeat", "off");
                    root.player.mpc("single", "off");
                }
            }
        }
    }

    // How far along, with the times either side
    Label {
        id: elapsed

        x: 14
        anchors.verticalCenter: progress.verticalCenter
        text: root.clock(root.player.elapsed)
        color: Theme.on_surface_variant
        font.family: Theme.monoFamily
        font.pixelSize: 11
    }

    LinearProgress {
        id: progress

        anchors.left: elapsed.right
        anchors.leftMargin: 10
        anchors.right: total.left
        anchors.rightMargin: 10
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        height: 10
        thickness: 4
        wavy: root.player.playing
        progress: root.player.duration > 0 ? root.player.elapsed / root.player.duration : 0

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            // Its margin reaches 6 past the line's start
            onClicked: mouse => root.player.mpc("seek", String(Math.round(Math.max(0, Math.min(1, (mouse.x - 6) / progress.width)) * root.player.duration)))
        }
    }

    Label {
        id: total

        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: progress.verticalCenter
        text: root.clock(root.player.duration)
        color: Theme.on_surface_variant
        font.family: Theme.monoFamily
        font.pixelSize: 11
    }
}
