import QtQuick
import Quickshell.Widgets
import "../.."
import "../../components"

// An episode on a series' page in the video menu: its still (with how far
// it's been watched), its number and title, "S02E03 · 22 min · aired",
// a line of its story, and a tick once it's been seen. Text only: the list
// draws the row's background and the sliding pick under it.
Item {
    id: root

    property var episode
    property bool current: false
    // The episode the series is up to
    property bool next: false
    property bool live: true

    readonly property alias hovered: mouse.containsMouse

    signal clicked
    signal activated

    height: 76

    function minutes(seconds) {
        const m = Math.round(seconds / 60);
        return m >= 60 ? `${Math.floor(m / 60)} h ${m % 60} min` : `${m} min`;
    }

    function aired(date) {
        if (!date)
            return "";
        const d = new Date(date + "T00:00:00");
        return isNaN(d) ? date : d.toLocaleDateString(Qt.locale(), "d MMM yyyy");
    }

    ClippingRectangle {
        id: still

        x: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 106
        height: 60
        radius: 8
        color: Theme.surface_container_highest

        Label {
            anchors.centerIn: parent
            visible: art.status !== Image.Ready
            text: root.episode?.episode ?? ""
            color: Theme.on_surface_variant
            font.family: Theme.monoFamily
            font.pixelSize: 16
        }

        Image {
            id: art

            anchors.fill: parent
            source: root.live && root.episode?.still ? `file://${root.episode.still}` : ""
            sourceSize.width: 212
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: status === Image.Ready ? (root.episode?.watched && !root.current ? 0.55 : 1) : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animFast
                }
            }
        }

        Rectangle {
            visible: (root.episode?.progress ?? 0) > 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 4
            color: Qt.rgba(0, 0, 0, 0.5)

            Rectangle {
                width: parent.width * Math.min(1, root.episode?.progress ?? 0)
                height: parent.height
                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 1)
            }
        }
    }

    Column {
        anchors.left: still.right
        anchors.leftMargin: 14
        anchors.right: trailing.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Label {
            anchors.verticalCenter: undefined
            width: parent.width
            text: `${root.episode?.episode ?? ""}.  ${root.episode?.title ?? ""}`
            color: root.current ? Theme.on_secondary_container : root.next ? Theme.primary : Theme.on_surface
            font.pixelSize: 14
            elide: Text.ElideRight
        }

        Label {
            anchors.verticalCenter: undefined
            width: parent.width
            text: {
                const e = root.episode;
                if (!e)
                    return "";
                const code = `S${String(e.season).padStart(2, "0")}E${String(e.episode).padStart(2, "0")}`;
                const where = e.position > 0 ? `${root.minutes(e.duration - e.position)} left` : e.duration ? root.minutes(e.duration) : "";
                return [code, where, root.aired(e.air_date)].filter(x => x).join("  ·  ");
            }
            color: root.current ? Theme.on_secondary_container : Theme.on_surface_variant
            opacity: root.current ? 0.8 : 1
            font.pixelSize: 12
            font.weight: Font.Normal
            elide: Text.ElideRight
        }

        Label {
            anchors.verticalCenter: undefined
            width: parent.width
            visible: text !== ""
            text: root.episode?.overview ?? ""
            color: root.current ? Theme.on_secondary_container : Theme.on_surface_variant
            opacity: root.current ? 0.7 : 0.8
            font.pixelSize: 11
            font.weight: Font.Normal
            elide: Text.ElideRight
        }
    }

    Row {
        id: trailing

        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        // Up next
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.next && !(root.episode?.watched ?? false)
            width: nextLabel.implicitWidth + 16
            height: 22
            radius: 11
            color: root.current ? Theme.primary : Theme.primary_container

            Label {
                id: nextLabel

                anchors.centerIn: parent
                text: (root.episode?.position ?? 0) > 0 ? "Carry on" : "Up next"
                color: root.current ? Theme.on_primary : Theme.on_primary_container
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.episode?.watched ?? false
            name: "task_alt"
            size: 20
            color: root.current ? Theme.on_secondary_container : Theme.primary
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
