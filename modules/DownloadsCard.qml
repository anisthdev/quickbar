import Quickshell
import QtQuick
import ".."
import "../components"

// Every unfinished download, newest first, whoever's it is: its app's
// badge and name, its title, a wavy progress bar while it downloads, how
// much is done and how fast, and the buttons its app offers (pause or
// resume, cancel or dismiss); a failed one stays with its error until
// dismissed. A click opens its app. From the DownloadHub singleton.
Dropdown {
    id: root

    menuWidth: 360
    title: "Downloads"
    onOpenChanged: if (open)
        cursor.currentIndex = -1
    // j/k/gg/G move over the downloads, Space or p pauses or resumes one,
    // x cancels or dismisses it, Enter or l opens its app
    keyHandler: event => {
        if (keys.handle(event))
            return true;
        const d = DownloadHub.active[cursor.currentIndex];
        if (event.key === Qt.Key_Space || event.key === Qt.Key_P) {
            if (d)
                toggleDownload(d);
            return true;
        }
        if (event.key === Qt.Key_X) {
            if (d)
                cancelDownload(d);
            return true;
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_L) {
            if (d)
                openDownload(d);
            return true;
        }
        return false;
    }

    // Pause or resume, whichever it offers
    function toggleDownload(d) {
        const action = ["pause", "resume"].find(a => d.actions?.includes(a));
        if (action)
            DownloadHub.act(d, action);
    }

    function cancelDownload(d) {
        const action = ["cancel", "dismiss"].find(a => d.actions?.includes(a));
        if (action)
            DownloadHub.act(d, action);
    }

    function openDownload(d) {
        DownloadHub.open(d);
        root.open = false;
    }

    RowCursor {
        id: cursor
        count: DownloadHub.active.length
    }

    ListKeys {
        id: keys
        list: cursor
    }

    Repeater {
        model: ScriptModel {
            values: DownloadHub.active.map(d => d.key)
        }

        Rectangle {
            id: row

            required property string modelData
            required property int index
            readonly property var download: DownloadHub.byKey[modelData] ?? {}
            readonly property bool first: index === 0
            readonly property bool last: index === DownloadHub.active.length - 1
            readonly property bool paused: download.state === "paused"
            readonly property bool failed: download.state === "error"
            readonly property bool downloading: download.state === "downloading"

            width: parent.width
            height: info.implicitHeight + 24
            topLeftRadius: first ? Theme.radius : 3
            topRightRadius: first ? Theme.radius : 3
            bottomLeftRadius: last ? Theme.radius : 3
            bottomRightRadius: last ? Theme.radius : 3
            color: Theme.surface_container_high

            // A click opens its app (the buttons are over this)
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openDownload(row.download)
            }

            // Its app's badge: the app's icon on a tonal square
            Rectangle {
                id: badge

                readonly property string source: DownloadHub.iconOf(row.download)

                x: 12
                y: 14
                width: 32
                height: 32
                radius: Theme.radius
                color: Theme.surface_container_highest

                Image {
                    anchors.centerIn: parent
                    visible: badge.source !== ""
                    width: 20
                    height: 20
                    source: badge.source
                    sourceSize.width: 40
                    sourceSize.height: 40
                    asynchronous: true
                }

                Icon {
                    anchors.centerIn: parent
                    visible: badge.source === ""
                    name: "arrow_downward"
                    size: 16
                    color: Theme.on_surface_variant
                }
            }

            Column {
                id: info

                anchors.left: badge.right
                anchors.leftMargin: 12
                y: 12
                width: parent.width - 56 - 12 - buttons.width
                spacing: 4

                // Whose it is
                Label {
                    anchors.verticalCenter: undefined
                    width: parent.width
                    text: DownloadHub.appNameOf(row.download)
                    color: Theme.on_surface_variant
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                Label {
                    anchors.verticalCenter: undefined
                    width: parent.width
                    text: row.download.title ?? ""
                    color: Theme.on_surface
                    font.pixelSize: 14
                    elide: Text.ElideMiddle
                }

                LinearProgress {
                    width: parent.width
                    progress: row.download.progress ?? 0
                    indeterminate: row.download.progress === null || row.download.state === "verifying" || row.download.state === "processing"
                    wavy: row.downloading
                    thickness: 4
                    color: row.failed ? Theme.error : row.paused ? Theme.outline : Theme.primary
                }

                Label {
                    anchors.verticalCenter: undefined
                    width: parent.width
                    visible: text !== ""
                    text: (row.failed ? row.download.error : row.download.detail) ?? ""
                    color: row.failed ? Theme.error : Theme.on_surface_variant
                    font.pixelSize: 12
                    font.weight: Font.Normal
                    elide: Text.ElideRight
                }
            }

            // The buttons its app offers
            Row {
                id: buttons

                readonly property var actions: row.download.actions ?? []

                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter

                // Pause or resume; for a failed download, try again
                IconButton {
                    visible: buttons.actions.includes("pause") || buttons.actions.includes("resume")
                    implicitWidth: 40
                    implicitHeight: 40
                    icon: buttons.actions.includes("pause") ? "media_pause" : row.failed ? "restart_alt" : "media_play_arrow"
                    iconSize: 18
                    color: Theme.on_surface_variant
                    onClicked: root.toggleDownload(row.download)
                }

                IconButton {
                    visible: buttons.actions.includes("cancel") || buttons.actions.includes("dismiss")
                    implicitWidth: 40
                    implicitHeight: 40
                    icon: "close"
                    iconSize: 18
                    color: Theme.on_surface_variant
                    onClicked: root.cancelDownload(row.download)
                }
            }

            // Focus ring
            Rectangle {
                anchors.fill: parent
                visible: cursor.currentIndex === row.index
                color: "transparent"
                border.width: 2
                border.color: Theme.primary
                topLeftRadius: row.topLeftRadius
                topRightRadius: row.topRightRadius
                bottomLeftRadius: row.bottomLeftRadius
                bottomRightRadius: row.bottomRightRadius
            }

            MenuReveal {
                target: row
                shown: root.open
                index: row.index + 1
            }
        }
    }

    Label {
        anchors.verticalCenter: undefined
        visible: DownloadHub.active.length === 0
        leftPadding: 8
        bottomPadding: 6
        text: DownloadHub.finished ? `${DownloadHub.finished.title} finished` : "Nothing downloading"
        color: Theme.on_surface_variant
        font.pixelSize: 14
        font.weight: Font.Normal
        width: parent.width
        elide: Text.ElideMiddle
    }
}
