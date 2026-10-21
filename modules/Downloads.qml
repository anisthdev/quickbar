import Quickshell.Io
import QtQuick
import ".."
import "../components"

// Downloads, torrents or the runner's (yt-dlp, scripts): the newest one as
// a ring filling up, with its percentage; hidden when nothing is
// downloading. A finished download stays a moment as a full ring with a
// check; one being filed spins. Click for all of them, with pause, resume
// and cancel. The data comes from the DownloadState singleton.
Pill {
    id: root

    readonly property var latest: DownloadState.active[0] ?? null

    padding: 8
    spacing: 6
    visible: DownloadState.active.length > 0 || DownloadState.finished !== null
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
            indeterminate: root.latest?.state === "verifying" || root.latest?.state === "processing"
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
        visible: root.latest !== null
        text: `${Math.floor((root.latest?.progress ?? 0) * 100)}%`
        color: Theme.on_background
        fontWeight: Font.DemiBold
    }

    Tooltip {
        owner: root
        shown: root.hovered && !card.open
        text: root.latest?.title ?? DownloadState.finished?.title ?? ""
        description: root.latest ? root.latest.detail : "Finished"
    }

    DownloadsCard {
        id: card
        owner: root
        onOpenChanged: DownloadState.watching = open
    }

    // `qs -p <dir> ipc call downloads toggle`
    IpcHandler {
        target: "downloads"

        function toggle(): void {
            card.toggle();
        }
    }
}
