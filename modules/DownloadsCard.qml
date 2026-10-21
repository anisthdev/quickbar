import Quickshell
import QtQuick
import ".."
import "../components"

// Every unfinished download, newest first: its name, a wavy progress bar
// while it downloads, how much is done and how fast, and pause or resume;
// the runner's (yt-dlp, scripts) also cancel, and a failed one stays with
// its error until dismissed. From the DownloadState singleton.
Dropdown {
    id: root

    menuWidth: 360
    title: "Downloads"
    onOpenChanged: if (open)
        cursor.currentIndex = -1
    // j/k/gg/G move over the downloads, Space or p pauses or resumes one,
    // x cancels or dismisses it
    keyHandler: event => {
        if (keys.handle(event))
            return true;
        const d = DownloadState.active[cursor.currentIndex];
        if (event.key === Qt.Key_Space || event.key === Qt.Key_P) {
            if (d)
                DownloadState.toggle(d);
            return true;
        }
        if (event.key === Qt.Key_X) {
            if (d)
                DownloadState.cancel(d);
            return true;
        }
        return false;
    }

    RowCursor {
        id: cursor
        count: DownloadState.active.length
    }

    ListKeys {
        id: keys
        list: cursor
    }

    Repeater {
        model: ScriptModel {
            values: DownloadState.active.map(d => d.key)
        }

        Rectangle {
            id: row

            required property string modelData
            required property int index
            readonly property var download: DownloadState.byKey[modelData] ?? {}
            readonly property bool first: index === 0
            readonly property bool last: index === DownloadState.active.length - 1
            readonly property bool paused: download.state === "paused"
            readonly property bool failed: download.state === "error"
            readonly property bool downloading: download.state === "downloading"

            width: parent.width
            height: info.implicitHeight + 28
            topLeftRadius: first ? Theme.radius : 3
            topRightRadius: first ? Theme.radius : 3
            bottomLeftRadius: last ? Theme.radius : 3
            bottomRightRadius: last ? Theme.radius : 3
            color: Theme.surface_container_high

            Column {
                id: info

                x: 16
                y: 14
                width: parent.width - 32 - buttons.width
                spacing: 4

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
                    indeterminate: row.download.state === "verifying" || row.download.state === "processing"
                    wavy: row.downloading
                    thickness: 4
                    color: row.failed ? Theme.error : row.paused ? Theme.outline : Theme.primary
                }

                Label {
                    anchors.verticalCenter: undefined
                    width: parent.width
                    text: row.download.detail ?? ""
                    color: row.failed ? Theme.error : Theme.on_surface_variant
                    font.pixelSize: 12
                    font.weight: Font.Normal
                    elide: Text.ElideRight
                }
            }

            Row {
                id: buttons

                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter

                // Pause or resume; for a failed download, try again
                IconButton {
                    visible: row.download.canPause ?? false
                    implicitWidth: 40
                    implicitHeight: 40
                    icon: row.failed ? "restart_alt" : row.paused ? "media_play_arrow" : "media_pause"
                    iconSize: 18
                    color: Theme.on_surface_variant
                    onClicked: DownloadState.toggle(row.download)
                }

                IconButton {
                    visible: row.download.canCancel ?? false
                    implicitWidth: 40
                    implicitHeight: 40
                    icon: "close"
                    iconSize: 18
                    color: Theme.on_surface_variant
                    onClicked: DownloadState.cancel(row.download)
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
        visible: DownloadState.active.length === 0
        leftPadding: 8
        bottomPadding: 6
        text: DownloadState.finished ? `${DownloadState.finished.title} finished` : "Nothing downloading"
        color: Theme.on_surface_variant
        font.pixelSize: 14
        font.weight: Font.Normal
        width: parent.width
        elide: Text.ElideMiddle
    }
}
