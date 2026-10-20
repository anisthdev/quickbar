import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import ".."

// Notification popups in the bottom right corner, newest at the bottom.
//
// Only one program can be the notification server. While quickbar runs it
// takes over from mako: mako is stopped first, and a watcher started here
// brings it back once quickbar exits, so switching bars switches the
// notifications along with them.
Scope {
    id: root

    // Never shown; mako hid these too
    readonly property var hiddenApps: ["Spotify"]
    // At most this many on screen; older ones wait their turn
    readonly property int maxShown: 4

    // key -> Notification, for the cards to pick up
    property var objects: ({})
    property int nextKey: 0

    function add(n) {
        if (root.hiddenApps.includes(n.appName))
            return;
        n.tracked = true;
        // A newer level of the same kind takes over the card on screen
        const sync = n.hints?.["x-canonical-private-synchronous"];
        if (sync) {
            for (let i = 0; i < repeater.count; i++) {
                const card = repeater.itemAt(i);
                if (card?.syncKey === sync && card.n && !card.leaving) {
                    objects[card.key] = n;
                    card.adopt(n);
                    return;
                }
            }
        }
        const key = nextKey++;
        objects[key] = n;
        cards.append({
            key: key
        });
    }

    function remove(key) {
        for (let i = 0; i < cards.count; i++) {
            if (cards.get(i).key === key) {
                cards.remove(i);
                break;
            }
        }
        delete objects[key];
    }

    // Stop mako, wait for it to let go of the name, and leave a watcher
    // behind (one at most, through the lock) to restart it after quickbar
    Process {
        running: true
        command: ["sh", "-c", `
            qs=$PPID
            pkill -x mako
            for _ in $(seq 50); do
                busctl --user status org.freedesktop.Notifications 2>/dev/null | grep -q '^Comm=mako$' || break
                sleep 0.1
            done
            setsid -f sh -c '
                exec 9>"$XDG_RUNTIME_DIR/quickbar-mako.lock"
                flock -n 9 || exit 0
                tail --pid="$1" -f /dev/null
                exec 9>&-
                pgrep -x mako >/dev/null || exec uwsm app -- mako
            ' sh "$qs" >/dev/null 2>&1 </dev/null
        `]
        onExited: server.active = true
    }

    LazyLoader {
        id: server

        NotificationServer {
            keepOnReload: true
            bodySupported: true
            bodyMarkupSupported: true
            actionsSupported: true
            imageSupported: true
            // Progress, as handoff's file transfers send it
            extraHints: ["value", "x-canonical-private-synchronous"]

            onNotification: n => root.add(n)
        }
    }

    ListModel {
        id: cards
    }

    PanelWindow {
        anchors {
            bottom: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        margins.bottom: 5
        margins.right: 5
        implicitWidth: 440
        // Fixed, so cards coming and going don't resize the surface every
        // frame; the mask keeps the empty part click-through
        implicitHeight: 900
        visible: cards.count > 0
        color: "transparent"
        // Hyprland's blur layer rule matches on this name (mako used it too)
        WlrLayershell.namespace: "notifications"
        WlrLayershell.layer: WlrLayer.Overlay
        mask: Region {
            item: stack
        }

        Column {
            id: stack

            anchors.bottom: parent.bottom
            width: parent.width

            Repeater {
                id: repeater

                model: cards

                NotificationCard {
                    required property int index

                    source: root.objects[key]
                    visible: index >= cards.count - root.maxShown
                    onFinished: root.remove(key)
                }
            }
        }
    }

    // `qs -p <dir> ipc call notifications dismiss`, e.g. from a keybind
    IpcHandler {
        target: "notifications"

        // The newest one
        function dismiss(): void {
            for (let i = cards.count - 1; i >= 0; i--) {
                const n = root.objects[cards.get(i).key];
                if (n) {
                    n.dismiss();
                    return;
                }
            }
        }

        function dismissAll(): void {
            for (let i = 0; i < cards.count; i++)
                root.objects[cards.get(i).key]?.dismiss();
        }
    }
}
