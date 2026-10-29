import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import ".."

// Notification popups in the bottom right corner, newest at the bottom.
//
// quickbar is the notification server (mako's D-Bus activation is
// overridden, so it can't take the name first).
Scope {
    id: root

    // Never shown; mako hid these too
    readonly property var hiddenApps: ["Spotify"]
    // At most this many on screen; older ones wait their turn
    readonly property int maxShown: 4

    // key -> Notification, for the cards to pick up
    property var objects: ({})
    property int nextKey: 0
    // A card has its reply field open
    readonly property bool typing: {
        repeater.count;
        for (let i = 0; i < repeater.count; i++) {
            if (repeater.itemAt(i)?.replying)
                return true;
        }
        return false;
    }

    function add(n) {
        if (root.hiddenApps.includes(n.appName))
            return;
        n.tracked = true;
        // Progress (a number in the "value" hint) is a download: the bar's
        // pill shows it, not a card (see DownloadHub). Not a level, though
        // (volume, brightness: they come with x-canonical-private-synchronous),
        // nor one replacing a card on screen (busy's "Done"), nor busy's
        // spinner (value "busy"); and a download that turns into a plain
        // message leaves the pill for a card.
        const onCard = Object.values(objects).some(o => o?.id === n.id);
        const level = n.hints?.["x-canonical-private-synchronous"] !== undefined;
        if (n.hints?.value !== undefined && !isNaN(Number(n.hints.value)) && !level && !onCard) {
            DownloadHub.addNotification(n);
            return;
        }
        DownloadHub.releaseNotification(n.id);
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

    LazyLoader {
        id: server

        active: true

        NotificationServer {
            keepOnReload: true
            bodySupported: true
            bodyMarkupSupported: true
            actionsSupported: true
            imageSupported: true
            // KDE's inline reply: an "inline-reply" action, answered with
            // the NotificationReplied signal
            inlineReplySupported: true
            // Progress, as handoff's file transfers send it
            extraHints: ["value", "x-canonical-private-synchronous", "x-kde-reply-placeholder-text"]

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
        // The keyboard only while a reply is being typed
        WlrLayershell.keyboardFocus: root.typing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
