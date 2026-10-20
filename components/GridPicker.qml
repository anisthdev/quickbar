import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."

// A picker of characters in a grid, the glyph and emoji pickers' shared
// window: in the rofi menus' place and shape (bottom centre, springing
// open), a title, a search field (focused on opening) and the characters
// each in a cell, the cells grouped as the other menus' rows are. Hovering
// a cell makes it current; `footerLeft` and `footerRight` say what the
// current one is. Enter or a click picks (`activated`), after closing.
//
// The owner filters: `entries` is what to show for `query`, each with a
// `char`.
//
// Keys: typing searches, the arrows, Tab or Ctrl+h/j/k/l move, Esc leaves
// the field for the grid, where h/j/k/l move, gg/G go to the ends, / or i
// search again, and q or Esc close. `extraKeys(event)` takes the grid's
// other keys, returning true when it used one.
Scope {
    id: root

    property string title
    property string placeholder
    property var entries: []
    property string footerLeft
    property string footerRight
    property string cellFont: Theme.fontFamily
    property real cellTextSize: 24
    // Between the field and the grid, while `headerShown`
    property Component header
    property bool headerShown: true
    property var extraKeys: event => false

    property int columns: 10
    property real cell: 52
    property int visibleRows: 6

    property bool open: false
    property bool typing: true
    readonly property string query: field.text
    readonly property int count: grid.count
    readonly property int currentIndex: grid.currentIndex
    readonly property var current: entries[grid.currentIndex] ?? null

    signal activated(var entry, int modifiers)

    function toggle() {
        open ? hide() : show();
    }

    function show() {
        field.text = "";
        grid.currentIndex = 0;
        grid.positionViewAtBeginning();
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

    function select(index) {
        if (index < 0 || index >= grid.count)
            return;
        // A long jump lands at once, rather than scrolling the way there
        if (Math.abs(index - grid.currentIndex) > columns * visibleRows)
            grid.positionViewAtIndex(index, GridView.Beginning);
        grid.currentIndex = index;
    }

    function move(dx, dy) {
        const i = grid.currentIndex + dx + dy * columns;
        if (i >= 0 && i < grid.count)
            grid.currentIndex = i;
    }

    function pick(modifiers) {
        if (!current)
            return;
        const entry = current;
        hide();
        activated(entry, modifiers);
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
                            root.select(grid.count - 1);
                        } else if (pendingG) {
                            pendingG = false;
                            root.select(0);
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
                        if (!root.extraKeys(event))
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
                    text: root.title
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
                        onTextChanged: {
                            grid.currentIndex = 0;
                            grid.positionViewAtBeginning();
                        }

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
                        text: root.placeholder
                        color: Theme.on_surface_variant
                        font.pixelSize: 16
                        font.weight: Font.Normal
                    }
                }

                Loader {
                    width: parent.width
                    active: root.header !== null
                    visible: active && root.headerShown
                    sourceComponent: root.header
                }

                // The cells, grouped as the other menus' rows are: round
                // outer corners, tight ones between. The pick's fill slides
                // from cell to cell over the cells (drawn on a layer of
                // their own, below) and under the characters
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
                    model: root.entries
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
                        id: cell

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
                        // follows the character
                        Rectangle {
                            parent: grid.contentItem
                            z: -1
                            x: cell.x + 1
                            y: cell.y + 1
                            width: cell.width - 2
                            height: cell.height - 2
                            topLeftRadius: cell.row === 0 && cell.column === 0 ? cell.outer : cell.inner
                            topRightRadius: cell.row === 0 && (cell.column === root.columns - 1 || cell.index === grid.count - 1) ? cell.outer : cell.inner
                            bottomLeftRadius: cell.lastInColumn && cell.column === 0 ? cell.outer : cell.inner
                            bottomRightRadius: cell.lastInColumn && (cell.column === root.columns - 1 || cell.index === grid.count - 1) ? cell.outer : cell.inner
                            color: hover.containsMouse && !cell.isCurrent ? Theme.surface_container_highest : Theme.surface_container_high
                        }

                        Text {
                            anchors.centerIn: parent
                            text: cell.modelData.char
                            font.family: root.cellFont
                            font.pixelSize: root.cellTextSize
                            color: cell.isCurrent ? Theme.on_secondary_container : Theme.on_surface
                        }

                        MouseArea {
                            id: hover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: grid.currentIndex = cell.index
                            onClicked: mouse => root.pick(mouse.modifiers)
                        }
                    }
                }

                // What the current one is
                Item {
                    width: parent.width
                    height: 20

                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        anchors.right: right.left
                        anchors.rightMargin: 12
                        elide: Text.ElideRight
                        text: root.footerLeft
                        color: Theme.on_surface
                        font.pixelSize: 14
                    }

                    Label {
                        id: right

                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        text: root.footerRight
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
}
