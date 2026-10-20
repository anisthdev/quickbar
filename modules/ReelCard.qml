import QtQuick
import Quickshell.Widgets
import ".."
import "../components"

// A card in the library (Reel): a poster (2:3), or a wide picture (16:9)
// with its caption over a scrim, for Continue watching and episodes. A bar
// along the bottom shows how far it's been watched. The current card of
// the active row grows and takes an outline.
Item {
    id: root

    property string image
    property bool wide: false
    property string caption
    property string subcaption
    // 0 to 1; 0 hides the bar
    property real progress: 0
    // Seen to the end: a Watched chip in the corner
    property bool watched: false
    property bool current: false
    // The row has the keys: only then does the current card stand out
    property bool active: false

    readonly property bool lit: current && active

    width: wide ? 320 : 150
    height: wide ? 180 : 225
    z: lit ? 1 : 0
    scale: lit ? 1.1 : 1

    Behavior on scale {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }
    }

    // Rounded all the way through: the picture and the bar too
    ClippingRectangle {
        id: frame

        anchors.fill: parent
        radius: 14
        color: Theme.surface_container_high

        Image {
            anchors.fill: parent
            source: root.image ? "file://" + root.image : ""
            sourceSize.width: root.wide ? 640 : 300
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
        }

        // Darkens the top, so the watched check reads on any picture
        Rectangle {
            visible: root.watched
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 72
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.rgba(0, 0, 0, 0.7)
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
        }

        // The caption's scrim
        Rectangle {
            visible: root.caption !== ""
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 76
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: 1
                    color: Qt.rgba(0, 0, 0, 0.78)
                }
            }
        }

        Column {
            visible: root.caption !== ""
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 12
            anchors.bottomMargin: root.progress > 0 ? 16 : 10
            spacing: 0

            Label {
                anchors.verticalCenter: undefined
                width: parent.width
                visible: root.subcaption !== ""
                text: root.subcaption
                elide: Text.ElideRight
                color: Qt.rgba(1, 1, 1, 0.75)
                font.pixelSize: 12
            }

            Label {
                anchors.verticalCenter: undefined
                width: parent.width
                text: root.caption
                elide: Text.ElideRight
                color: "white"
                font.pixelSize: 15
                font.weight: Theme.titleWeight
            }
        }

        // How far it's been watched
        Rectangle {
            visible: root.progress > 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 5
            color: Qt.rgba(1, 1, 1, 0.25)

            Rectangle {
                width: parent.width * Math.min(1, root.progress)
                height: parent.height
                color: Theme.primary
            }
        }
    }

    // Watched: a chip in the corner, over the darkened top
    Rectangle {
        visible: root.watched
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        width: watchedRow.implicitWidth + 18
        height: 26
        radius: 13
        // Solid, to read on any picture
        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 1)

        Row {
            id: watchedRow

            anchors.centerIn: parent
            spacing: 4

            Icon {
                name: "task_alt"
                size: 16
                color: Qt.rgba(Theme.on_primary.r, Theme.on_primary.g, Theme.on_primary.b, 1)
            }

            Label {
                text: "Watched"
                color: Qt.rgba(Theme.on_primary.r, Theme.on_primary.g, Theme.on_primary.b, 1)
                font.pixelSize: 12
                font.weight: Theme.titleWeight
            }
        }
    }

    // The outline of the current card
    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: frame.radius + 4
        color: "transparent"
        border.width: 3
        border.color: Theme.on_surface
        opacity: root.lit ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animFast
            }
        }
    }
}
