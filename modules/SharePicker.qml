import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import ".."
import "../components"

// What a screen share shows, in hyprland-share-picker's place: the
// Hyprland portal runs scripts/share-picker, which asks here over a socket.
// One of the rofi-shaped menus, in sections: the screens, the windows
// (with their apps' icons) and a region, with a live preview of the
// current pick on top. The region is picked with the region selector, after which the
// share starts; cancelling it comes back here.
//
// The last row says whether the app may share the same thing again
// without asking (a restore token); r or Enter on it switches it.
//
// Keys are the menus': j/k, gg/G, / to filter, Enter or l to share, r for
// the restore token, q or Esc to cancel.
Scope {
    id: root

    required property var region

    readonly property string socketDir: Quickshell.env("XDG_RUNTIME_DIR") + "/quickbar"
    readonly property string socketPath: socketDir + "/sharepicker.sock"

    // The share being asked about: { socket, request }
    property var current: null
    // Let the app share it again without asking
    property bool restore: false
    // Closed for the region selector, not cancelled
    property bool pickingRegion: false
    // What the preview shows: the current row, while it's a screen or window
    property var previewing: null

    function normal(address) {
        return String(address ?? "").replace(/^0x/, "").toLowerCase();
    }

    function toplevelOf(address) {
        const want = normal(address);
        return want === "" ? null : Hyprland.toplevels.values.find(t => normal(t.address) === want)?.wayland ?? null;
    }

    function iconOf(cls) {
        return DesktopEntries.heuristicLookup(cls)?.icon ?? cls;
    }

    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    readonly property var entries: {
        if (!current)
            return [];
        const rows = Quickshell.screens.map(s => ({
                    key: `screen:${s.name}`,
                    // A laptop's panel names only its maker's code
                    label: /^(eDP|LVDS|DSI)/.test(s.name) ? "Built-in screen" : s.model || s.name,
                    subtitle: `${s.name} · ${s.width}×${s.height}`,
                    icon: "video-display",
                    section: "Screens",
                    kind: "screen",
                    screen: s
                }));
        for (const w of current.request.windows)
            rows.push({
                key: `window:${w.handle}`,
                label: w.title || w.class,
                subtitle: w.class,
                icon: iconOf(w.class),
                section: "Windows",
                kind: "window",
                handle: w.handle,
                toplevel: toplevelOf(w.address)
            });
        rows.push({
            key: "region",
            label: "Select a region",
            subtitle: "Drag it out, or click a window",
            icon: "screengrab",
            section: "Region",
            kind: "region"
        });
        rows.push({
            key: "token",
            label: "Let it share this again without asking",
            on: restore,
            accent: true,
            kind: "token"
        });
        return rows;
    }

    // A line from scripts/share-picker
    function receive(socket, line) {
        let m;
        try {
            m = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (m.op !== "pick")
            return;
        // One at a time
        if (current) {
            socket.write(JSON.stringify({
                cancelled: true
            }) + "\n");
            socket.flush();
            return;
        }
        current = {
            socket: socket,
            request: m
        };
        restore = m.allowToken ?? false;
        menu.show();
    }

    // Answers the share: { selection, restore } or { cancelled }
    function finish(answer) {
        const job = current;
        if (!job)
            return;
        current = null;
        pickingRegion = false;
        if (job.socket.connected) {
            job.socket.write(JSON.stringify(answer) + "\n");
            job.socket.flush();
        }
        menu.hide();
    }

    function share(selection) {
        finish({
            selection: selection,
            restore: restore
        });
    }

    function activate(entry) {
        switch (entry?.kind) {
        case "screen":
            share(`screen:${entry.screen.name}`);
            break;
        case "window":
            share(`window:${entry.handle}`);
            break;
        case "region":
            pickingRegion = true;
            menu.hide();
            // Once the menu has folded away, so the frozen screen is clear of it
            regionTimer.restart();
            break;
        case "token":
            restore = !restore;
            break;
        }
    }

    Timer {
        id: regionTimer

        interval: 200
        onTriggered: root.region.ask(r => {
            if (!root.current)
                return;
            if (r) {
                root.share(`region:${r.screen}@${r.x},${r.y},${r.width},${r.height}`);
            } else {
                // Back to the choices
                root.pickingRegion = false;
                menu.show();
            }
        })
    }

    LauncherWindow {
        id: menu

        title: "Share"
        panelWidth: 600
        maxRows: 7
        closeOnPick: false
        entryKey: "key"
        entries: root.entries
        header: preview
        onActivated: entry => root.activate(entry)
        onCurrentEntryChanged: if (currentEntry?.kind === "screen" || currentEntry?.kind === "window")
            root.previewing = currentEntry
        else if (currentEntry?.kind === "region")
            root.previewing = {
                kind: "screen",
                screen: root.focusedScreen
            }
        // Closed by q, Esc or a click outside: cancelled
        onOpenChanged: if (!open && root.current && !root.pickingRegion)
            root.finish({
                cancelled: true
            })
        extraKeys: event => {
            if (event.key !== Qt.Key_R || event.modifiers & (Qt.ControlModifier | Qt.AltModifier))
                return false;
            root.restore = !root.restore;
            return true;
        }
    }

    // The current pick, live
    Component {
        id: preview

        Rectangle {
            readonly property var source: root.previewing?.kind === "screen" ? root.previewing.screen : root.previewing?.toplevel ?? null

            implicitHeight: 220
            radius: Theme.radius
            color: Theme.surface_container_high

            ScreencopyView {
                id: view

                // Fits the box, keeping its shape
                readonly property real fit: sourceSize.width > 0 ? Math.min((parent.width - 16) / sourceSize.width, (parent.height - 16) / sourceSize.height) : 0

                anchors.centerIn: parent
                width: sourceSize.width * fit
                height: sourceSize.height * fit
                captureSource: menu.open ? parent.source : null
                live: true
            }

            Label {
                anchors.centerIn: parent
                visible: !view.hasContent
                text: "No preview"
                color: Theme.on_surface_variant
            }
        }
    }

    // The socket lives in a folder of quickbar's own
    Process {
        running: true
        command: ["mkdir", "-p", "-m", "700", root.socketDir]
        onExited: server.active = true
    }

    SocketServer {
        id: server

        path: root.socketPath
        handler: Socket {
            id: client

            parser: SplitParser {
                onRead: line => root.receive(client, line)
            }
            // The portal gave up on it
            onConnectionStateChanged: if (!connected && root.current?.socket === client) {
                root.current = null;
                root.pickingRegion = false;
                menu.hide();
            }
        }
    }
}
