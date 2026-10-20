import Quickshell.Io
import QtQuick
import ".."
import "../components"

// Transmission's downloads: the newest one as a ring filling up, with its
// percentage; hidden when nothing is downloading. A finished download stays
// a moment as a full ring with a check. Click for all of them, with pause
// and resume. The data comes from the Transmission singleton.
Pill {
    id: root

    readonly property var latest: Transmission.active[0] ?? null

    padding: 8
    spacing: 6
    visible: Transmission.active.length > 0 || Transmission.finished !== null
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
            progress: root.latest ? root.latest.percentDone : 1
            indeterminate: root.latest !== null && (root.latest.status === 1 || root.latest.status === 2)
            color: root.latest?.status === 0 ? Theme.outline : Theme.primary
        }

        Icon {
            anchors.centerIn: parent
            name: root.latest ? "arrow_downward" : "check"
            size: 12
            color: Theme.on_background
        }
    }

    RollingText {
        visible: root.latest !== null
        text: `${Math.floor((root.latest?.percentDone ?? 0) * 100)}%`
        color: Theme.on_background
        fontWeight: Font.DemiBold
    }

    Tooltip {
        owner: root
        shown: root.hovered && !card.open
        text: root.latest?.name ?? Transmission.finished?.name ?? ""
        description: root.latest ? Transmission.state(root.latest) : "Finished"
    }

    DownloadsCard {
        id: card
        owner: root
        onOpenChanged: Transmission.watching = open
    }

    // `qs -p <dir> ipc call downloads toggle`
    IpcHandler {
        target: "downloads"

        function toggle(): void {
            card.toggle();
        }
    }
}
