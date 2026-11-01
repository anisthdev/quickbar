import QtQuick
import Quickshell.Widgets
import "../.."
import "../../components"

// A title in the video menu's grid: its poster (2:3) with how far it's
// been watched along the poster's foot, a chip in the corner (Watched, or
// the episode a series is up to), and its title and where it's at under
// it. The grid draws the pick's fill behind it.
Item {
    id: root

    property var item
    property bool current: false
    // Under the title: "42 min left", "S02E05 · 5 of 24", "2009 · 1 h 35 min"
    property string status
    // 0 to 1; 0 hides the bar
    property real progress: 0
    property bool watched: false
    // The next episode's code, for a series under way
    property string next
    // Posters load only while the menu shows, so closing frees them
    property bool live: true

    signal clicked
    signal activated

    Rectangle {
        anchors.fill: parent
        radius: Theme.cardRadius
        color: Qt.alpha(Theme.on_surface, 0.06)
        visible: mouse.containsMouse && !root.current
    }

    ClippingRectangle {
        id: poster

        x: 8
        y: 8
        width: root.width - 16
        height: width * 1.5
        radius: 12
        color: Theme.surface_container_highest

        // No poster: the title, in its place
        Label {
            anchors.verticalCenter: undefined
            anchors.fill: parent
            anchors.margins: 12
            visible: art.status !== Image.Ready
            text: root.item?.title ?? ""
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
            color: Theme.on_surface_variant
            font.pixelSize: 15
            font.weight: Theme.titleWeight
        }

        Image {
            id: art

            anchors.fill: parent
            source: root.live && root.item?.poster ? `file://${root.item.poster}` : ""
            sourceSize.width: Math.ceil(poster.width * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
            opacity: status === Image.Ready ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animNormal
                }
            }
        }

        // Darkens the foot, so the bar reads on any picture
        Rectangle {
            visible: root.progress > 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 36
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: 1
                    color: Qt.rgba(0, 0, 0, 0.6)
                }
            }
        }

        // How far it's been watched
        Rectangle {
            visible: root.progress > 0
            x: 8
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            width: parent.width - 16
            height: 4
            radius: 2
            color: Qt.rgba(1, 1, 1, 0.3)

            Rectangle {
                width: Math.max(height, parent.width * Math.min(1, root.progress))
                height: parent.height
                radius: 2
                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 1)
            }
        }
    }

    // Watched, or the episode it's up to: solid, to read on any picture
    Rectangle {
        anchors.top: poster.top
        anchors.right: poster.right
        anchors.margins: 8
        visible: root.watched || root.next !== ""
        width: chipRow.implicitWidth + 14
        height: 24
        radius: 12
        color: root.watched ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 1) : Qt.rgba(Theme.secondary_container.r, Theme.secondary_container.g, Theme.secondary_container.b, 1)

        Row {
            id: chipRow

            anchors.centerIn: parent
            spacing: 3

            Icon {
                visible: root.watched
                name: "task_alt"
                size: 14
                color: Qt.rgba(Theme.on_primary.r, Theme.on_primary.g, Theme.on_primary.b, 1)
            }

            Label {
                text: root.watched ? "Watched" : root.next
                color: root.watched ? Qt.rgba(Theme.on_primary.r, Theme.on_primary.g, Theme.on_primary.b, 1) : Theme.on_secondary_container
                font.family: root.watched ? Theme.fontFamily : Theme.monoFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }
    }

    Column {
        anchors.top: poster.bottom
        anchors.topMargin: 8
        x: 10
        width: root.width - 20
        spacing: 1

        Label {
            anchors.verticalCenter: undefined
            width: parent.width
            text: root.item?.title ?? ""
            color: root.current ? Theme.on_secondary_container : Theme.on_surface
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        Label {
            anchors.verticalCenter: undefined
            width: parent.width
            text: root.status
            color: root.current ? Theme.on_secondary_container : Theme.on_surface_variant
            opacity: root.current ? 0.8 : 1
            font.pixelSize: 11
            font.weight: Font.Normal
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onDoubleClicked: root.activated()
    }
}
