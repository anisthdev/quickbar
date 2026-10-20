import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."

// A menu in the rofi menus' place and shape: bottom centre, a title and a
// grouped list (ListItem rows) of entries with app icons. It springs open
// upwards and folds back down, by shape only.
//
// Keyboard first, with vim keys: j/k (or the arrows, Tab) move, gg/G go to
// the ends, Ctrl+d/Ctrl+u by half a page, Enter or l runs the pick
// (`activated`), q or Esc closes. The filter field is there but not
// focused: / or i (or a click) focuses it, typing filters, Enter runs, Esc
// goes back to the list keeping the filter, and Esc there clears it. With
// `startTyping` it opens in the field instead, for menus mostly used by
// typing (the app launcher). The mouse works too.
//
// Matches rank by where the typed text falls: the start of the label,
// then the start of a word in it, then anywhere in it, then an entry's
// `keywords`. Ties keep the entries' own order.
//
// entries: [{ label, icon }, …] plus whatever the owner needs; icon is a
// theme icon name or a path. Long lists scroll after `maxRows` rows, and
// with `bigCurrent` the current row grows to show its picture large (box
// art, covers).
Scope {
    id: root

    property string title
    property string placeholder: "Filter…"
    property var entries: []
    // Rows shown before the list scrolls; 0 shows them all
    property int maxRows: 0
    property bool bigCurrent: false
    property bool open: false
    // Typing into the filter
    property bool filtering: false
    property bool startTyping: false
    property real panelWidth: 500

    signal activated(var entry)

    readonly property var shown: {
        const q = field.text.trim().toLowerCase();
        if (q === "")
            return entries;
        const rank = e => {
            const label = e.label.toLowerCase();
            if (label.startsWith(q))
                return 0;
            if (label.split(/[\s\-_.]+/).some(w => w.startsWith(q)))
                return 1;
            if (label.includes(q))
                return 2;
            if ((e.keywords ?? "").toLowerCase().includes(q))
                return 3;
            return -1;
        };
        return entries.map((e, i) => ({
                    e,
                    i,
                    r: rank(e)
                })).filter(m => m.r >= 0).sort((a, b) => a.r - b.r || a.i - b.i).map(m => m.e);
    }

    function show() {
        field.text = "";
        filtering = false;
        list.currentIndex = 0;
        open = true;
        if (startTyping)
            startFilter();
        else
            keys.forceActiveFocus();
    }

    function startFilter() {
        filtering = true;
        field.forceActiveFocus();
    }

    function stopFilter() {
        filtering = false;
        keys.forceActiveFocus();
    }

    function hide() {
        open = false;
    }

    function toggle() {
        open ? hide() : show();
    }

    function run(index) {
        const entry = shown[index];
        if (!entry)
            return;
        hide();
        root.activated(entry);
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

            property real fullHeight: content.y + content.implicitHeight + (root.title !== "" ? 20 : 18)

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            width: root.panelWidth
            height: Math.max(0, fullHeight * window.reveal)
            radius: Theme.cardRadius
            color: Theme.surface_container
            clip: true

            // Filtering shrinks and grows it
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

            ListKeys {
                id: listKeys

                list: list
                halfPage: Math.max(1, Math.floor((root.maxRows || list.count) / 2))
            }

            // The list's keys, while not typing a filter
            Item {
                id: keys

                Keys.onPressed: event => {
                    if (listKeys.handle(event)) {
                        event.accepted = true;
                        return;
                    }
                    switch (event.key) {
                    case Qt.Key_Tab:
                        listKeys.move(1);
                        break;
                    case Qt.Key_Backtab:
                        listKeys.move(-1);
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                    case Qt.Key_L:
                        root.run(list.currentIndex);
                        break;
                    case Qt.Key_Slash:
                    case Qt.Key_I:
                        root.startFilter();
                        break;
                    case Qt.Key_Escape:
                        // A filter left on goes first
                        if (field.text !== "")
                            field.text = "";
                        else
                            root.hide();
                        break;
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
                // Less room above without a title
                y: root.title !== "" ? 26 : 18
                width: parent.width - 40
                spacing: 14

                Label {
                    anchors.verticalCenter: undefined
                    visible: root.title !== ""
                    leftPadding: 2
                    height: 34
                    verticalAlignment: Text.AlignVCenter
                    text: root.title
                    color: Theme.primary
                    // rofi's 20 pt
                    font.pixelSize: 26
                    font.weight: Theme.titleWeight
                    roundness: Theme.titleRoundness
                }

                // The filter, outlined while typing into it
                Rectangle {
                    width: parent.width
                    height: 46
                    radius: Theme.radius
                    color: Theme.surface_container_highest
                    border.width: root.filtering ? 2 : 0
                    border.color: Theme.primary

                    // A click focuses it, as / does
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.IBeamCursor
                        onClicked: root.startFilter()
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
                        font.weight: Font.Medium
                        clip: true
                        onTextChanged: list.currentIndex = 0

                        // Typing filters; these move and leave
                        Keys.onPressed: event => {
                            const ctrl = event.modifiers & Qt.ControlModifier;
                            switch (event.key) {
                            case Qt.Key_Escape:
                                root.stopFilter();
                                break;
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                                root.run(list.currentIndex);
                                break;
                            case Qt.Key_Down:
                            case Qt.Key_Tab:
                                listKeys.move(1);
                                break;
                            case Qt.Key_Up:
                            case Qt.Key_Backtab:
                                listKeys.move(-1);
                                break;
                            case Qt.Key_J:
                            case Qt.Key_N:
                                if (!ctrl)
                                    return;
                                listKeys.move(1);
                                break;
                            case Qt.Key_K:
                            case Qt.Key_P:
                                if (!ctrl)
                                    return;
                                listKeys.move(-1);
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

                ListView {
                    id: list

                    readonly property real rowHeight: 58
                    readonly property real bigRowHeight: 112
                    readonly property int rows: root.maxRows > 0 ? Math.min(count, root.maxRows) : count

                    visible: count > 0
                    width: parent.width
                    height: rows * rowHeight + Math.max(0, rows - 1) * spacing + (root.bigCurrent && count > 0 ? bigRowHeight - rowHeight : 0)
                    spacing: 2
                    clip: true
                    interactive: rows < count
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.shown
                    // Keep the current row in view as the keys move it
                    highlightRangeMode: ListView.ApplyRange
                    preferredHighlightBegin: 0
                    preferredHighlightEnd: height
                    // The pick's fill slides from row to row: it sits above
                    // the rows' backgrounds (drawn on a layer of their own,
                    // below) and under their icons and text
                    highlightFollowsCurrentItem: true
                    highlightMoveDuration: 220
                    highlightMoveVelocity: -1
                    highlightResizeDuration: Theme.animNormal
                    highlightResizeVelocity: -1
                    highlight: Rectangle {
                        radius: Theme.radius
                        color: Theme.secondary_container
                        // Fades in with its row as the menu opens
                        opacity: list.currentItem?.opacity ?? 1
                    }

                    // The grouped list rows of the other menus
                    delegate: ListItem {
                        id: item

                        required property var modelData
                        required property int index
                        readonly property bool isCurrent: ListView.isCurrentItem
                        readonly property bool big: root.bigCurrent && isCurrent
                        // A row starts at its size, and opening jumps to the first
                        // one; only moving the pick animates
                        property bool settled: false

                        Component.onCompleted: Qt.callLater(() => {
                            if (item)
                                item.settled = true;
                        })

                        width: list.width
                        rowHeight: big ? list.bigRowHeight : list.rowHeight
                        // Its own easing below moves the content with it
                        animateHeight: false
                        image: {
                            const name = modelData.icon ?? "";
                            return name.startsWith("/") ? `file://${name}` : Quickshell.iconPath(name, true);
                        }
                        imageSize: big ? 96 : 32

                        Behavior on rowHeight {
                            enabled: item.settled && !openAnim.running
                            NumberAnimation {
                                duration: Theme.animNormal
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.emphasizedDecel
                            }
                        }
                        Behavior on imageSize {
                            enabled: item.settled && !openAnim.running
                            NumberAnimation {
                                duration: Theme.animNormal
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.emphasizedDecel
                            }
                        }
                        text: modelData.label
                        first: index === 0
                        last: index === list.count - 1
                        clickable: true
                        // The background is drawn below, under the sliding fill
                        drawBackground: false
                        shown: root.open
                        revealIndex: Math.min(index, 8)
                        onClicked: root.run(index)
                        onHoveredChanged: if (hovered)
                            list.currentIndex = index

                        // The row's background, moved under the list's
                        // highlight; it follows the row, fading in with it
                        Rectangle {
                            parent: list.contentItem
                            z: -1
                            x: item.x
                            y: item.y
                            width: item.width
                            height: item.height
                            topLeftRadius: item.topCorners
                            topRightRadius: item.topCorners
                            bottomLeftRadius: item.bottomCorners
                            bottomRightRadius: item.bottomCorners
                            color: item.hovered && !item.isCurrent ? Theme.surface_container_highest : Theme.surface_container_high
                            opacity: item.opacity
                        }
                    }
                }

                Label {
                    anchors.verticalCenter: undefined
                    visible: list.count === 0
                    leftPadding: 4
                    text: "Nothing matches"
                    color: Theme.on_surface_variant
                    font.pixelSize: 14
                    font.weight: Font.Normal
                }
            }
        }
    }
}
