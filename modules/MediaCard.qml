import QtQuick
import ".."
import "../components"

// Android 16 style media card for mpd: art and song details, a wavy seek
// bar, and shuffle / previous / play-pause / next / repeat. The play button
// is a circle while paused and a rounded square while playing, morphing
// between them. Fed by Mpd.qml.
Dropdown {
    id: root

    required property var player

    function clock(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        const pad = n => String(n).padStart(2, "0");
        return s >= 3600 ? `${Math.floor(s / 3600)}:${pad(Math.floor(s / 60) % 60)}:${pad(s % 60)}` : `${Math.floor(s / 60)}:${pad(s % 60)}`;
    }

    // Repeat cycles off -> all -> one -> off, as on Android
    function cycleRepeat() {
        if (!player.repeat)
            player.mpc("repeat", "on");
        else if (!player.single)
            player.mpc("single", "on");
        else {
            player.mpc("repeat", "off");
            player.mpc("single", "off");
        }
    }

    menuWidth: 340

    // Art and song
    Row {
        id: song

        width: parent.width
        spacing: 14
        topPadding: 4

        AlbumArt {
            size: 72
            source: root.player.art
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 72 - 14
            spacing: 2

            Label {
                anchors.verticalCenter: undefined
                width: parent.width
                text: root.player.title
                color: Theme.on_surface
                font.pixelSize: 16
                elide: Text.ElideRight
            }

            Label {
                anchors.verticalCenter: undefined
                width: parent.width
                visible: text !== ""
                text: root.player.artist
                color: Theme.on_surface_variant
                font.pixelSize: 13
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Label {
                anchors.verticalCenter: undefined
                width: parent.width
                visible: text !== ""
                text: root.player.album
                color: Theme.on_surface_variant
                font.pixelSize: 12
                font.weight: Font.Medium
                opacity: 0.8
                elide: Text.ElideRight
            }
        }

        MenuReveal {
            target: song
            shown: root.open
        }
    }

    // Seek bar and times
    Column {
        id: seek

        width: parent.width
        spacing: 2
        topPadding: 6

        WavyProgress {
            width: parent.width
            progress: root.player.duration > 0 ? root.player.elapsed / root.player.duration : 0
            playing: root.player.playing
            onSeek: fraction => root.player.mpc("seek", String(Math.round(fraction * root.player.duration)))
        }

        Item {
            width: parent.width
            height: 16

            Label {
                anchors.left: parent.left
                text: root.clock(root.player.elapsed)
                color: Theme.on_surface_variant
                font.pixelSize: 11
                font.features: {
                    "tnum": 1
                }
            }

            Label {
                anchors.right: parent.right
                text: root.clock(root.player.duration)
                color: Theme.on_surface_variant
                font.pixelSize: 11
                font.features: {
                    "tnum": 1
                }
            }
        }

        MenuReveal {
            target: seek
            shown: root.open
            index: 1
        }
    }

    // Controls
    Item {
        id: controls

        width: parent.width
        height: 64

        Row {
            anchors.centerIn: parent
            spacing: 10

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 40
                implicitHeight: 40
                icon: "media_shuffle"
                iconSize: 20
                color: root.player.random ? Theme.primary : Theme.on_surface_variant
                onClicked: root.player.mpc("random")
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 48
                implicitHeight: 48
                icon: "media_skip_previous"
                iconSize: 26
                onClicked: root.player.mpc("prev")
            }

            // Play/pause: a circle while paused, a rounded square while
            // playing
            Rectangle {
                id: playButton

                anchors.verticalCenter: parent.verticalCenter
                width: 60
                height: 60
                radius: root.player.playing ? 18 : 30
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
                    size: 30
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
                implicitWidth: 48
                implicitHeight: 48
                icon: "media_skip_next"
                iconSize: 26
                onClicked: root.player.mpc("next")
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 40
                implicitHeight: 40
                icon: root.player.repeat && root.player.single ? "media_repeat_one" : "media_repeat"
                iconSize: 20
                color: root.player.repeat ? Theme.primary : Theme.on_surface_variant
                onClicked: root.cycleRepeat()
            }
        }

        MenuReveal {
            target: controls
            shown: root.open
            index: 2
        }
    }
}
