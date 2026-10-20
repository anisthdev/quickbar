import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import ".."
import "../components"

// The Nerd Font glyph picker, in rofi-nerdy's place (Super+Ctrl+N): the
// glyphs alone in a grid, in the rofi menus' place and shape (bottom centre,
// springing open), with the search field focused. The current glyph's name
// and codepoint show under the grid; hovering a glyph makes it current.
// Enter pastes the glyph where the user was typing (see Paste),
// Shift+Enter only copies it.
//
// Keys: typing searches (word starts first: "home" finds md-home), the
// arrows or Ctrl+h/j/k/l move, Esc leaves the field for the grid, where
// h/j/k/l move, gg/G go to the ends, / or i search again, and q or Esc
// close.
//
// The names come from Nerd Fonts' glyphnames.json (MIT), kept in data/.
Scope {
    id: root

    readonly property int columns: 10
    readonly property real cell: 52
    readonly property int visibleRows: 6

    property bool open: false
    property bool typing: true
    // [{ name, char, code }]
    property var glyphs: []

    readonly property var shown: {
        const q = field.text.trim().toLowerCase();
        if (q === "")
            return glyphs;
        const rank = g => {
            if (g.name.startsWith(q))
                return 0;
            if (g.name.split(/[-_]/).some(w => w.startsWith(q)))
                return 1;
            if (g.name.includes(q))
                return 2;
            return g.code === q ? 0 : -1;
        };
        return glyphs.map((g, i) => ({
                    g,
                    i,
                    r: rank(g)
                })).filter(m => m.r >= 0).sort((a, b) => a.r - b.r || a.i - b.i).map(m => m.g);
    }
    readonly property var current: shown[grid.currentIndex] ?? null

    function toggle() {
        open ? hide() : show();
    }

    function show() {
        Paste.capture();
        field.text = "";
        grid.currentIndex = 0;
        type();
        open = true;
    }

    function hide() {
        open = false;
    }

    function type() {
        typing = true;
        field.forceActiveFocus();
    }

    function browse() {
        typing = false;
        keys.forceActiveFocus();
    }

    function move(dx, dy) {
        const i = grid.currentIndex + dx + dy * columns;
        if (i >= 0 && i < grid.count)
            grid.currentIndex = i;
    }

    function pick(modifiers) {
        if (!current)
            return;
        hide();
        Paste.copy({
            text: current.char
        }, !(modifiers & Qt.ShiftModifier));
    }

    FileView {
        path: Qt.resolvedUrl("../data/glyphnames.json").toString().replace("file://", "")
        blockLoading: false
        onLoaded: {
            const glyphs = [];
            const names = JSON.parse(text());
            for (const name in names) {
                if (name !== "METADATA")
                    glyphs.push({
                        name,
                        char: names[name].char,
                        code: names[name].code
                    });
            }
            root.glyphs = glyphs;
        }
    }

    PanelWindow {
        id: window

        property real reveal: 0

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        // Mapped from opening until the fold-away has finished
        visible: false
        // Blurred, without Hyprland's layer slide (see looknfeel.lua)
        WlrLayershell.namespace: "quickbar-overlay"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Connections {
            target: root
            function onOpenChanged() {
                if (root.open) {
                    closeAnim.stop();
                    window.visible = true;
                    openAnim.restart();
                } else {
                    openAnim.stop();
                    closeAnim.restart();
                }
            }
        }

        NumberAnimation {
            id: openAnim

            target: window
            property: "reveal"
            to: 1
            duration: 320
            easing.type: Easing.OutBack
            easing.overshoot: 0.8
        }

        NumberAnimation {
            id: closeAnim

            target: window
            property: "reveal"
            to: 0
            duration: 150
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasizedAccel
            onFinished: window.visible = false
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.hide()
        }

        Rectangle {
            id: panel

            property real fullHeight: content.y + content.implicitHeight + 18

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            width: root.columns * root.cell + 40
            height: Math.max(0, fullHeight * window.reveal)
            radius: Theme.cardRadius
            color: Theme.surface_container
            clip: true

            Behavior on fullHeight {
                enabled: root.open && !openAnim.running
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.emphasizedDecel
                }
            }

            MouseArea {
                anchors.fill: parent
            }

            // The grid's keys, while not typing
            Item {
                id: keys

                // The first g of a gg
                property bool pendingG: false

                Timer {
                    id: gTimer

                    interval: 600
                    onTriggered: keys.pendingG = false
                }

                Keys.onPressed: event => {
                    const g = event.key === Qt.Key_G && event.text === "g";
                    if (!g)
                        pendingG = false;
                    switch (event.key) {
                    case Qt.Key_H:
                    case Qt.Key_Left:
                        root.move(-1, 0);
                        break;
                    case Qt.Key_L:
                    case Qt.Key_Right:
                        root.move(1, 0);
                        break;
                    case Qt.Key_K:
                    case Qt.Key_Up:
                        root.move(0, -1);
                        break;
                    case Qt.Key_J:
                    case Qt.Key_Down:
                        root.move(0, 1);
                        break;
                    case Qt.Key_G:
                        // A capital can come without Shift held (wtype)
                        if (event.text === "G") {
                            grid.currentIndex = grid.count - 1;
                        } else if (pendingG) {
                            pendingG = false;
                            grid.currentIndex = 0;
                        } else {
                            pendingG = true;
                            gTimer.restart();
                        }
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                    case Qt.Key_Space:
                        root.pick(event.modifiers);
                        break;
                    case Qt.Key_Slash:
                    case Qt.Key_I:
                        root.type();
                        break;
                    case Qt.Key_Escape:
                    case Qt.Key_Q:
                        root.hide();
                        break;
                    default:
                        return;
                    }
                    event.accepted = true;
                }
            }

            Column {
                id: content

                x: 20
                y: 26
                width: parent.width - 40
                spacing: 14

                Label {
                    anchors.verticalCenter: undefined
                    leftPadding: 2
                    height: 34
                    verticalAlignment: Text.AlignVCenter
                    text: "Glyphs"
                    color: Theme.primary
                    font.pixelSize: 26
                    font.weight: Theme.titleWeight
                    roundness: Theme.titleRoundness
                }

                // The search, outlined while typing into it
                Rectangle {
                    width: parent.width
                    height: 46
                    radius: Theme.radius
                    color: Theme.surface_container_highest
                    border.width: root.typing ? 2 : 0
                    border.color: Theme.primary

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.IBeamCursor
                        onClicked: root.type()
                    }

                    Icon {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        name: "search"
                        size: 20
                        color: Theme.on_surface_variant
                    }

                    TextInput {
                        id: field

                        anchors.left: parent.left
                        anchors.leftMargin: 46
                        anchors.right: parent.right
                        anchors.rightMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.on_surface
                        selectionColor: Theme.primary
                        selectedTextColor: Theme.on_primary
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        clip: true
                        onTextChanged: grid.currentIndex = 0

                        Keys.onPressed: event => {
                            const ctrl = event.modifiers & Qt.ControlModifier;
                            switch (event.key) {
                            case Qt.Key_Escape:
                                root.browse();
                                break;
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                                root.pick(event.modifiers);
                                break;
                            case Qt.Key_Left:
                            case Qt.Key_Right:
                                // Through the text first, as in any field
                                return;
                            case Qt.Key_Down:
                                root.move(0, 1);
                                break;
                            case Qt.Key_Up:
                                root.move(0, -1);
                                break;
                            case Qt.Key_Tab:
                                root.move(1, 0);
                                break;
                            case Qt.Key_Backtab:
                                root.move(-1, 0);
                                break;
                            case Qt.Key_H:
                            case Qt.Key_J:
                            case Qt.Key_K:
                            case Qt.Key_L:
                                if (!ctrl)
                                    return;
                                root.move(event.key === Qt.Key_H ? -1 : event.key === Qt.Key_L ? 1 : 0, event.key === Qt.Key_K ? -1 : event.key === Qt.Key_J ? 1 : 0);
                                break;
                            default:
                                return;
                            }
                            event.accepted = true;
                        }
                    }

                    Label {
                        anchors.left: field.left
                        visible: field.text === ""
                        text: "Search Nerd Font glyphs…"
                        color: Theme.on_surface_variant
                        font.pixelSize: 16
                        font.weight: Font.Normal
                    }
                }

                // The glyphs, each in its own cell, the cells grouped as the
                // other menus' rows are: round outer corners, tight ones
                // between. The pick's fill slides from cell to cell over the
                // cells (drawn on a layer of their own, below) and under the
                // glyphs
                GridView {
                    id: grid

                    readonly property int rows: Math.ceil(count / root.columns)

                    visible: count > 0
                    width: parent.width
                    height: Math.min(rows, root.visibleRows) * root.cell
                    cellWidth: root.cell
                    cellHeight: root.cell
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.shown
                    highlightFollowsCurrentItem: true
                    highlightMoveDuration: 140
                    highlightRangeMode: GridView.ApplyRange
                    preferredHighlightBegin: 0
                    preferredHighlightEnd: height
                    highlight: Item {
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: Theme.radius
                            color: Theme.secondary_container
                        }
                    }

                    delegate: Item {
                        id: glyph

                        required property var modelData
                        required property int index
                        readonly property bool isCurrent: GridView.isCurrentItem
                        readonly property int column: index % root.columns
                        readonly property int row: Math.floor(index / root.columns)
                        // The grid's own corners are round, the rest tight
                        readonly property real outer: Theme.radius
                        readonly property real inner: 3
                        // The cell above the last row's end, when that row
                        // is short, closes the grid's right edge
                        readonly property bool lastInColumn: index + root.columns >= grid.count

                        width: root.cell
                        height: root.cell

                        // The cell, moved under the grid's highlight; it
                        // follows the glyph
                        Rectangle {
                            parent: grid.contentItem
                            z: -1
                            x: glyph.x + 1
                            y: glyph.y + 1
                            width: glyph.width - 2
                            height: glyph.height - 2
                            topLeftRadius: glyph.row === 0 && glyph.column === 0 ? glyph.outer : glyph.inner
                            topRightRadius: glyph.row === 0 && (glyph.column === root.columns - 1 || glyph.index === grid.count - 1) ? glyph.outer : glyph.inner
                            bottomLeftRadius: glyph.lastInColumn && glyph.column === 0 ? glyph.outer : glyph.inner
                            bottomRightRadius: glyph.lastInColumn && (glyph.column === root.columns - 1 || glyph.index === grid.count - 1) ? glyph.outer : glyph.inner
                            color: hover.containsMouse && !glyph.isCurrent ? Theme.surface_container_highest : Theme.surface_container_high
                        }

                        Text {
                            anchors.centerIn: parent
                            text: glyph.modelData.char
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 24
                            color: glyph.isCurrent ? Theme.on_secondary_container : Theme.on_surface
                        }

                        MouseArea {
                            id: hover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: grid.currentIndex = glyph.index
                            onClicked: mouse => root.pick(mouse.modifiers)
                        }
                    }
                }

                // The current glyph's name and codepoint
                Item {
                    width: parent.width
                    height: 20

                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        text: root.current?.name ?? (root.glyphs.length > 0 ? "Nothing matches" : "")
                        color: Theme.on_surface
                        font.pixelSize: 14
                    }

                    Label {
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        text: root.current ? `U+${root.current.code.toUpperCase()}` : ""
                        color: Theme.on_surface_variant
                        font.pixelSize: 13
                        font.features: {
                            "tnum": 1
                        }
                    }
                }
            }
        }
    }

    // `qs -p <dir> ipc call glyphs toggle`, e.g. from Super+Ctrl+N
    IpcHandler {
        target: "glyphs"

        function toggle(): void {
            root.toggle();
        }
    }
}
