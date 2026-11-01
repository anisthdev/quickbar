import Quickshell
import QtQuick
import ".."
import "../components"

// Downloads, anyone's (see docs/downloads.md): the newest one as a ring
// filling up, with its percentage, and how many more there are; hidden when
// nothing is downloading. A finished download stays a moment as a full ring
// with a check; one being filed spins. Click for all of them, each with its
// app's badge and buttons. The data comes from the DownloadHub singleton.
Pill {
    id: root

    readonly property var latest: DownloadHub.active[0] ?? null

    padding: 8
    spacing: 6
    visible: DownloadHub.active.length > 0 || DownloadHub.finished !== null
    clickable: true
    onClicked: card.toggle()

    // The ring, with an arrow inside, or a check once it's done
    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        height: 22

        CircularProgress {
            anchors.centerIn: parent
            size: 22
            thickness: 2.5
            progress: root.latest ? root.latest.progress : 1
            indeterminate: root.latest !== null && (root.latest.progress === null || root.latest.state === "verifying" || root.latest.state === "processing")
            color: root.latest?.state === "error" ? Theme.error : root.latest?.state === "paused" ? Theme.outline : Theme.primary
        }

        Icon {
            anchors.centerIn: parent
            name: !root.latest ? "check" : root.latest.state === "error" ? "close" : "arrow_downward"
            size: 12
            color: Theme.on_background
        }
    }

    RollingText {
        visible: root.latest !== null && root.latest.progress !== null
        text: `${Math.floor((root.latest?.progress ?? 0) * 100)}%`
        color: Theme.on_background
        fontWeight: Font.DemiBold
    }

    // How many more
    Label {
        visible: DownloadHub.active.length > 1
        text: `+${DownloadHub.active.length - 1}`
        color: Theme.on_surface_variant
        font.pixelSize: 12
    }

    Tooltip {
        owner: root
        shown: root.hovered && !card.open
        text: root.latest?.title ?? DownloadHub.finished?.title ?? ""
        description: root.latest ? root.latest.detail : "Finished"
    }

    DownloadsCard {
        id: card
        owner: root
        onOpenChanged: DownloadHub.watching = open
    }

    // `qs -c quickbar ipc call downloads toggle`, through BarIpc: only the bar on
    // the focused monitor opens it
    Connections {
        target: BarIpc
        function onToggled(name, monitor) {
            if (name === "downloads" && monitor === root.QsWindow.window?.screen?.name)
                card.toggle();
        }
    }
}
