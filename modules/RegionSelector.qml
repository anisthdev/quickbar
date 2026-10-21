import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import ".."
import "../components"

// Pick a part of the screen, then do something with it, after end-4's
// region selector. The focused screen is frozen first (so a menu or a
// video holds still), dimmed, and a drag marks a region; a click takes the
// window under the pointer instead. A toolbar below the region then copies
// it as a screenshot, opens it in satty, copies its text, translates it or
// searches it with Google Lens (scripts/region does each).
//
// Keys: Enter or c copies, e edits, t copies the text, r translates, l
// searches with Lens, a takes the whole screen, Esc closes. Opened for one
// action (`ipc call region open text`), picking does it straight away.
Scope {
    id: root

    readonly property string script: Quickshell.shellDir + "/scripts/region"
    readonly property string frozen: `${Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"}/quickbar/region.png`
    readonly property var actions: [
        {
            id: "copy",
            label: "Copy",
            icon: "content_copy",
            key: "c"
        },
        {
            id: "edit",
            label: "Edit",
            icon: "edit",
            key: "e"
        },
        {
            id: "text",
            label: "Text",
            icon: "document_scanner",
            key: "t"
        },
        {
            id: "translate",
            label: "Translate",
            icon: "translate",
            key: "r"
        },
        {
            id: "lens",
            label: "Lens",
            icon: "image_search",
            key: "l"
        }
    ]

    property bool open: false
    // What picking does at once, or "" for the toolbar
    property string preset
    property var screen: null
    // Busting the image cache: each freeze is a new picture in one file
    property double stamp: 0
    // The windows on show, in the screen's coordinates, topmost first
    property var windows: []
    // The region picked, or null
    property var picked: null

    function show(action) {
        if (open || freezer.running)
            return;
        preset = actions.some(a => a.id === action) ? action : "";
        const name = Hyprland.focusedMonitor?.name ?? "";
        screen = Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0];
        picked = null;
        windows = [];
        clients.running = true;
        freezer.command = [root.script, "freeze", screen.name, root.frozen];
        freezer.running = true;
    }

    function hide() {
        open = false;
        picked = null;
    }

    // The region picked, in the frozen picture's pixels
    function geometry() {
        const r = image.sourceSize.width / window.width;
        const p = picked;
        return `${Math.round(p.width * r)}x${Math.round(p.height * r)}+${Math.round(p.x * r)}+${Math.round(p.y * r)}`;
    }

    function run(action) {
        if (!picked || picked.width < 2 || picked.height < 2)
            return;
        Quickshell.execDetached([root.script, action, root.frozen, geometry()]);
        hide();
    }

    function pick(region) {
        picked = region;
        if (preset)
            run(preset);
    }

    // The topmost window on show at a point
    function windowAt(x, y) {
        return windows.find(w => x >= w.x && x < w.x + w.width && y >= w.y && y < w.y + w.height) ?? null;
    }

    Process {
        id: freezer

        onExited: code => {
            if (code !== 0)
                return;
            root.stamp = Date.now();
            root.open = true;
        }
    }

    // The windows on the frozen screen's workspace, for a click to take one
    Process {
        id: clients

        command: ["sh", "-c", "hyprctl -j monitors; echo; hyprctl -j clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parts = text.split(/\n(?=\[)/);
                    const monitor = JSON.parse(parts[0]).find(m => m.name === root.screen?.name);
                    const shown = [monitor.activeWorkspace.id, monitor.specialWorkspace?.id].filter(id => id);
                    root.windows = JSON.parse(parts[1]).filter(c => c.mapped && !c.hidden && shown.includes(c.workspace.id)).sort((a, b) => a.focusHistoryID - b.focusHistoryID).map(c => ({
                                x: c.at[0] - monitor.x,
                                y: c.at[1] - monitor.y,
                                width: c.size[0],
                                height: c.size[1]
                            }));
                } catch (e) {
                    root.windows = [];
                }
            }
        }
    }

    PanelWindow {
        id: window

        screen: root.screen
        visible: root.open
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "black"
        // Without Hyprland's layer slide (see looknfeel.lua)
        WlrLayershell.namespace: "quickbar-overlay"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        onVisibleChanged: if (visible)
            keys.forceActiveFocus()

        Image {
            id: image

            anchors.fill: parent
            source: root.stamp ? `file://${root.frozen}?${root.stamp}` : ""
            cache: false
            smooth: true
        }

        // The region as it's dragged, else the one picked, else the window
        // under the pointer
        readonly property var region: mouse.dragging ? mouse.dragRect : root.picked ?? mouse.hovered
        readonly property var shown: region ?? {
            x: 0,
            y: 0,
            width: 0,
            height: 0
        }

        // Everything but the region, dimmed
        Repeater {
            model: [
                {
                    x: 0,
                    y: 0,
                    width: window.width,
                    height: window.shown.y
                },
                {
                    x: 0,
                    y: window.shown.y + window.shown.height,
                    width: window.width,
                    height: window.height - window.shown.y - window.shown.height
                },
                {
                    x: 0,
                    y: window.shown.y,
                    width: window.shown.x,
                    height: window.shown.height
                },
                {
                    x: window.shown.x + window.shown.width,
                    y: window.shown.y,
                    width: window.width - window.shown.x - window.shown.width,
                    height: window.shown.height
                }
            ]

            Rectangle {
                required property var modelData

                x: modelData.x
                y: modelData.y
                width: Math.max(0, modelData.width)
                height: Math.max(0, modelData.height)
                color: "black"
                opacity: 0.5
            }
        }

        Rectangle {
            visible: window.region !== null
            x: window.shown.x - 2
            y: window.shown.y - 2
            width: window.shown.width + 4
            height: window.shown.height + 4
            color: "transparent"
            radius: 4
            border.width: 2
            border.color: Theme.primary
        }

        // Its size, above it (or inside, at the top of the screen)
        Rectangle {
            visible: window.region !== null && window.shown.width > 0
            x: Math.min(window.shown.x, window.width - width - 8)
            y: window.shown.y >= height + 10 ? window.shown.y - height - 8 : window.shown.y + 8
            width: sizeLabel.implicitWidth + 16
            height: 24
            radius: 12
            color: Theme.surface_container

            Label {
                id: sizeLabel

                anchors.centerIn: parent
                text: {
                    const r = image.sourceSize.width / Math.max(1, window.width);
                    return `${Math.round(window.shown.width * r)} × ${Math.round(window.shown.height * r)}`;
                }
                color: Theme.on_surface
                font.pixelSize: 12
                font.features: {
                    "tnum": 1
                }
            }
        }

        MouseArea {
            id: mouse

            property point start
            property bool dragging: false
            property var dragRect: null
            property var hovered: null

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.CrossCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onPositionChanged: event => {
                if (!pressed) {
                    hovered = root.picked ? null : root.windowAt(event.x, event.y);
                    return;
                }
                if (!dragging && Math.hypot(event.x - start.x, event.y - start.y) > 4)
                    dragging = true;
                if (dragging)
                    dragRect = {
                        x: Math.min(start.x, event.x),
                        y: Math.min(start.y, event.y),
                        width: Math.abs(event.x - start.x),
                        height: Math.abs(event.y - start.y)
                    };
            }
            onPressed: event => {
                if (event.button === Qt.RightButton) {
                    root.hide();
                    return;
                }
                start = Qt.point(event.x, event.y);
                dragging = false;
            }
            onReleased: event => {
                if (event.button !== Qt.LeftButton)
                    return;
                if (dragging) {
                    dragging = false;
                    root.pick(dragRect);
                } else {
                    const w = root.windowAt(event.x, event.y);
                    if (w)
                        root.pick(w);
                }
                hovered = null;
            }
        }

        // What to do with the region, below it, or above it when there's
        // no room, kept on the screen
        Rectangle {
            id: toolbar

            readonly property real below: window.shown.y + window.shown.height + 12

            visible: root.picked !== null && !mouse.dragging && !root.preset
            x: Math.max(8, Math.min(window.shown.x + (window.shown.width - width) / 2, window.width - width - 8))
            y: below + height + 8 <= window.height ? below : Math.max(8, window.shown.y - height - 12)
            width: tools.implicitWidth + 12
            height: 52
            radius: 26
            color: Theme.surface_container

            Row {
                id: tools

                anchors.centerIn: parent
                spacing: 2

                Repeater {
                    model: root.actions

                    Rectangle {
                        id: tool

                        required property var modelData

                        width: toolRow.implicitWidth + 28
                        height: 40
                        radius: 20
                        color: toolMouse.containsMouse ? Theme.secondary_container : "transparent"

                        Row {
                            id: toolRow

                            anchors.centerIn: parent
                            spacing: 8

                            Icon {
                                name: tool.modelData.icon
                                size: 18
                                color: toolMouse.containsMouse ? Theme.on_secondary_container : Theme.on_surface
                            }

                            Label {
                                text: tool.modelData.label
                                color: toolMouse.containsMouse ? Theme.on_secondary_container : Theme.on_surface
                                font.pixelSize: 14
                            }

                            Label {
                                text: tool.modelData.key
                                color: Theme.outline
                                font.family: Theme.monoFamily
                                font.pixelSize: 12
                            }
                        }

                        MouseArea {
                            id: toolMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.run(tool.modelData.id)
                        }
                    }
                }

                IconButton {
                    implicitWidth: 40
                    implicitHeight: 40
                    icon: "close"
                    iconSize: 18
                    color: Theme.on_surface_variant
                    onClicked: root.hide()
                }
            }
        }

        // A hint while nothing is picked
        Rectangle {
            visible: root.picked === null && !mouse.dragging
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 32
            width: hint.implicitWidth + 32
            height: 40
            radius: 20
            color: Theme.surface_container

            Label {
                id: hint

                anchors.centerIn: parent
                text: {
                    const what = root.actions.find(a => a.id === root.preset)?.label;
                    return `${what ? what + ": d" : "D"}rag a region, or click a window  ·  a for the whole screen  ·  Esc to cancel`;
                }
                color: Theme.on_surface
                font.pixelSize: 14
            }
        }

        Item {
            id: keys

            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.hide();
                } else if (event.key === Qt.Key_A) {
                    root.pick({
                        x: 0,
                        y: 0,
                        width: window.width,
                        height: window.height
                    });
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.run("copy");
                } else {
                    const action = root.actions.find(a => a.key === event.text);
                    if (!action)
                        return;
                    root.run(action.id);
                }
                event.accepted = true;
            }
        }
    }

    // `qs -p <dir> ipc call region open ""` for the toolbar, or with an
    // action (copy, edit, text, translate, lens) to do it on picking
    IpcHandler {
        target: "region"

        function open(action: string): void {
            root.show(action);
        }

        function toggle(): void {
            if (root.open)
                root.hide();
            else
                root.show("");
        }
    }
}
