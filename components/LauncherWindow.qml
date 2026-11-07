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
// typing (the calculator). The mouse works too.
//
// Matches rank by where the typed text falls: the start of the label,
// then the start of a word in it, then anywhere in it, then an entry's
// `keywords`. Ties keep the entries' own order.
//
// entries: [{ label, icon }, …] plus whatever the owner needs; icon is a
// theme icon name or a path, `emoji` shows in its place, and `subtitle`, `trailing` (a short state,
// e.g. "80%"), `on` (true or false: a switch, for a row that turns a thing
// on and off), `keys` (keycaps, e.g. ["Super", "Q"]), `trailingIcon` (one
// of icons/, e.g. a pin), `checked` (a check mark) and `accent` (a row standing apart in the tertiary colour, as a
// page's on/off switch) are optional. Rows with a `section` are grouped
// under it as a heading, each run of one section its own group. Long lists scroll
// after `maxRows` rows, and with `bigCurrent` the current row grows to show
// its picture large (box art, covers).
//
// For menus with pages (the control panel): with `canGoBack`, a back arrow
// shows by the title, and it, h, Left or Backspace (and Esc with no
// filter) emit `back`; `replay()` brings the rows
// in again for a new page; `header` goes between the title and the field
// (a slider), `footer` under the rest (the calculator's answer);
// `extraKeys` gets the keys first. Setting `prompt` turns the field into a password field showing it: Enter emits `submitted`, Esc
// `promptCancelled`; with `promptSecret` off it's plain text (a note), and
// the rows below are only there to look at.
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
    property bool canGoBack: false
    // Off where picks open pages or switch things in place
    property bool closeOnPick: true
    // An entry field naming each entry for good (e.g. "key"): changed
    // entries then update their rows in place instead of rebuilding the
    // list, so a refresh doesn't move the pick
    property string entryKey: ""
    property var extraKeys: null
    property Component header: null
    // Under everything else (the calculator's answer)
    property Component footer: null
    property string prompt: ""
    property bool promptSecret: true
    // The field's icon, from icons/
    property string fieldIcon: "search"
    // The field under the rows instead of over them, where it's for
    // writing rather than filtering (quick note)
    property bool fieldAtBottom: false
    // A dialog: in the middle of a dimmed screen, solid (unblurred, so the
    // dimming isn't blurred too); the polkit prompt
    property bool modal: false
    // Off for a moment by replay(), so the rows reveal again
    property bool revealed: true

    // The modifiers held for the last pick (none for a click), e.g. Shift
    // for an alternative action
    property int pickModifiers: 0
    // The entry the pick is on, for keys acting on it (extraKeys)
    readonly property var currentEntry: shown[list.currentIndex] ?? null
    // What's in the field, for owners working on it as it's typed
    readonly property alias typed: field.text

    // Move the pick, e.g. after the owner reordered the entries
    function select(index) {
        list.currentIndex = Math.max(0, Math.min(list.count - 1, index));
    }

    signal activated(var entry)
    signal back
    signal submitted(string text)
    signal promptCancelled

    // A new page: no filter, the pick at `index`, the rows coming in again
    function replay(index) {
        field.text = "";
        stopFilter();
        list.currentIndex = index ?? 0;
        revealed = false;
        Qt.callLater(() => {
            root.revealed = true;
            // The new rows are laid out from the pick, as the top one;
            // whatever fits above it comes back in view
            if (list.currentIndex < list.rows)
                list.positionViewAtBeginning();
        });
    }

    onPromptChanged: {
        field.text = "";
        if (prompt !== "")
            startFilter();
        else if (open)
            stopFilter();
    }

    readonly property var shown: {
        const q = prompt !== "" ? "" : field.text.trim().toLowerCase();
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

    // Empties the field, e.g. for another try at a password
    function clearField() {
        field.text = "";
    }

    // Puts text in the field with its first `selected` characters selected,
    // to type over (a file name's stem); without, the cursor goes to the end
    function fill(text, selected) {
        field.text = text;
        if (selected)
            field.select(0, selected);
        else
            field.cursorPosition = text.length;
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
        if (closeOnPick)
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
        // Blurred, without Hyprland's layer slide (see looknfeel.lua); a
        // dialog without the blur
        WlrLayershell.namespace: root.modal ? "quickbar-dialog" : "quickbar-overlay"
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

        // A dialog's dimming
        Rectangle {
            anchors.fill: parent
            visible: root.modal
            color: "black"
            opacity: 0.45 * Math.min(1, window.reveal)
        }

        Rectangle {
            id: panel

            property real fullHeight: content.y + content.implicitHeight + (root.title !== "" ? 20 : 18)

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: root.modal ? undefined : parent.bottom
            anchors.bottomMargin: 16
            anchors.verticalCenter: root.modal ? parent.verticalCenter : undefined
            width: root.panelWidth
            height: Math.max(0, fullHeight * window.reveal)
            radius: Theme.cardRadius
            color: root.modal ? Qt.rgba(Theme.surface_container.r, Theme.surface_container.g, Theme.surface_container.b, 1) : Theme.surface_container
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
                    if ((root.extraKeys && root.extraKeys(event)) || listKeys.handle(event)) {
                        event.accepted = true;
                        return;
                    }
                    switch (event.key) {
                    case Qt.Key_H:
                    case Qt.Key_Left:
                    case Qt.Key_Backspace:
                        if (!root.canGoBack)
                            return;
                        root.back();
                        break;
                    case Qt.Key_Tab:
                        listKeys.move(1);
                        break;
                    case Qt.Key_Backtab:
                        listKeys.move(-1);
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                    case Qt.Key_L:
                        root.pickModifiers = event.modifiers;
                        root.run(list.currentIndex);
                        break;
                    case Qt.Key_Slash:
                    case Qt.Key_I:
                        root.startFilter();
                        break;
                    case Qt.Key_Escape:
                        // A filter left on goes first, then the page
                        if (field.text !== "")
                            field.text = "";
                        else if (root.canGoBack)
                            root.back();
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

                Row {
                    visible: root.title !== ""
                    height: 34
                    spacing: 4

                    IconButton {
                        visible: root.canGoBack
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "chevron"
                        iconSize: 22
                        color: Theme.primary
                        onClicked: root.back()
                    }

                    Label {
                        leftPadding: root.canGoBack ? 0 : 2
                        height: 34
                        verticalAlignment: Text.AlignVCenter
                        text: root.title
                        color: Theme.primary
                        // rofi's 20 pt
                        font.pixelSize: 26
                        font.weight: Theme.titleWeight
                        roundness: Theme.titleRoundness
                    }
                }

                Loader {
                    width: parent.width
                    active: root.header !== null
                    visible: active
                    sourceComponent: root.header
                }

                // The filter, outlined while typing into it; or the prompt
                Rectangle {
                    id: fieldBox

                    // Under the rows: moving it out and back in puts it
                    // last in the column
                    Component.onCompleted: if (root.fieldAtBottom) {
                        parent = null;
                        parent = content;
                    }

                    width: parent?.width ?? 0
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
                        name: root.fieldIcon
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
                        echoMode: root.prompt !== "" && root.promptSecret ? TextInput.Password : TextInput.Normal
                        onTextChanged: if (root.prompt === "")
                            list.currentIndex = 0

                        // Typing filters; these move and leave
                        Keys.onPressed: event => {
                            const ctrl = event.modifiers & Qt.ControlModifier;
                            if (root.prompt !== "") {
                                if (event.key === Qt.Key_Escape)
                                    root.promptCancelled();
                                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                    root.submitted(field.text);
                                else
                                    return;
                                event.accepted = true;
                                return;
                            }
                            switch (event.key) {
                            case Qt.Key_Escape:
                                root.stopFilter();
                                break;
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                                root.pickModifiers = event.modifiers;
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
                        text: root.prompt || root.placeholder
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
                    // Room for a section's heading over its first row
                    readonly property real headingHeight: 30
                    readonly property real sectionGap: 10

                    // The heading's room over row `index`, if it starts a section
                    function gapOf(index) {
                        const section = root.shown[index]?.section ?? "";
                        if (section === "" || section === (root.shown[index - 1]?.section ?? ""))
                            return 0;
                        return index === 0 ? headingHeight : headingHeight + sectionGap;
                    }

                    // A row growing under the pick slips past the highlight
                    // range, which only looks as the pick moves; it's followed
                    // here, down to the last frame of its growing
                    function keepBigInView() {
                        const slot = currentItem;
                        if (!slot?.big)
                            return;
                        // The rows' places, caught up with their heights
                        forceLayout();
                        const top = slot.y + slot.gap;
                        const bottom = top + slot.row.height;
                        if (bottom > contentY + height)
                            contentY = bottom - height;
                        else if (top < contentY)
                            contentY = top;
                    }

                    // Over the rows shown before it scrolls
                    readonly property real gaps: {
                        let sum = 0;
                        for (let i = 0; i < rows; i++)
                            sum += gapOf(i);
                        return sum;
                    }

                    visible: count > 0
                    width: parent.width
                    height: rows * rowHeight + Math.max(0, rows - 1) * spacing + gaps + (currentItem?.big ? bigRowHeight - rowHeight : 0)
                    spacing: 2
                    clip: true
                    interactive: rows < count
                    boundsBehavior: Flickable.StopAtBounds
                    model: ScriptModel {
                        values: root.shown
                        objectProp: root.entryKey
                    }
                    // Keep the current row in view as the keys move it
                    highlightRangeMode: ListView.ApplyRange
                    preferredHighlightBegin: 0
                    preferredHighlightEnd: height
                    // Jumps (gg, G, Ctrl+d/u) bring their row into view at
                    // once: the range alone lags a move behind across rows
                    // not built yet
                    property int lastIndex: 0
                    onCurrentIndexChanged: {
                        if (Math.abs(currentIndex - lastIndex) > 1) {
                            const index = currentIndex;
                            Qt.callLater(() => list.positionViewAtIndex(index, ListView.Contain));
                        }
                        lastIndex = currentIndex;
                        Qt.callLater(list.keepBigInView);
                    }
                    // The pick's fill slides from row to row: it sits above
                    // the rows' backgrounds (drawn on a layer of their own,
                    // below) and under their icons and text
                    // (placed by hand: the current item holds its heading too)
                    highlightFollowsCurrentItem: false
                    highlight: Rectangle {
                        id: pickFill

                        // Not to slide in from the top on opening
                        property bool settled: false

                        Component.onCompleted: Qt.callLater(() => settled = true)

                        y: (list.currentItem?.y ?? 0) + (list.currentItem?.gap ?? 0)
                        width: list.width
                        height: list.currentItem?.row.height ?? 0
                        radius: Theme.radius
                        color: Theme.secondary_container
                        // Fades in with its row as the menu opens
                        // No pick while the field asks for text
                        opacity: root.prompt !== "" ? 0 : list.currentItem?.row.opacity ?? 1

                        Behavior on y {
                            enabled: pickFill.settled
                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on height {
                            NumberAnimation {
                                duration: Theme.animNormal
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.emphasizedDecel
                            }
                        }
                    }

                    // The grouped list rows of the other menus, each with
                    // room over it for its section's heading if it starts one
                    delegate: Item {
                        id: slot

                        required property var modelData
                        required property int index
                        readonly property real gap: list.gapOf(index)
                        readonly property alias row: item
                        readonly property bool big: item.big

                        width: list.width
                        height: gap + item.height
                        onYChanged: if (ListView.isCurrentItem)
                            Qt.callLater(list.keepBigInView)
                        onHeightChanged: if (ListView.isCurrentItem)
                            Qt.callLater(list.keepBigInView)

                        Label {
                            anchors.verticalCenter: undefined
                            visible: slot.gap > 0
                            x: 4
                            y: slot.gap - list.headingHeight + 4
                            text: slot.modelData.section ?? ""
                            color: Theme.primary
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            // Comes in with its row
                            opacity: item.opacity
                        }

                        ListItem {
                            id: item

                            readonly property var modelData: slot.modelData
                            readonly property int index: slot.index
                            readonly property bool isCurrent: slot.ListView.isCurrentItem
                            // An entry can opt out (`big: false`), e.g. a text row among pictures
                            readonly property bool big: root.bigCurrent && isCurrent && (modelData.big ?? true)
                            // A row starts at its size, and opening jumps to the first
                            // one; only moving the pick animates
                            property bool settled: false

                            Component.onCompleted: Qt.callLater(() => {
                                if (item)
                                    item.settled = true;
                            })

                            function pick() {
                                root.pickModifiers = 0;
                                root.run(index);
                            }

                            width: list.width
                            rowHeight: big ? list.bigRowHeight : list.rowHeight
                            // Its own easing below moves the content with it
                            animateHeight: false
                            image: {
                                const name = modelData.icon ?? "";
                                // Only while shown, so closing frees the
                                // decoded icons and previews
                                if (name === "" || !window.visible)
                                    return "";
                                return name.startsWith("/") ? `file://${name}` : Quickshell.iconPath(name, true);
                            }
                            emoji: modelData.emoji ?? ""
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
                            subtitle: modelData.subtitle ?? ""
                            y: slot.gap
                            // An accent row stands alone, all corners round, and
                            // a section is a group of its own
                            first: index === 0 || modelData.accent || (root.shown[index - 1]?.accent ?? false) || (root.shown[index - 1]?.section ?? "") !== (modelData.section ?? "")
                            last: index === list.count - 1 || modelData.accent || (root.shown[index + 1]?.accent ?? false) || (root.shown[index + 1]?.section ?? "") !== (modelData.section ?? "")
                            clickable: true
                            // The background is drawn below, under the sliding fill
                            drawBackground: false
                            shown: root.open && root.revealed
                            revealIndex: Math.min(index, 8)
                            onClicked: pick()
                            onHoveredChanged: if (hovered)
                                list.currentIndex = index

                            Label {
                                visible: text !== ""
                                text: item.modelData.trailing ?? ""
                                color: Theme.on_surface_variant
                                font.pixelSize: 13
                            }

                            // Runs the row, whose owner changes the state
                            Switch {
                                visible: item.modelData.on !== undefined
                                checked: item.modelData.on ?? false
                                onToggled: item.pick()
                            }

                            // Keycaps
                            Row {
                                visible: (item.modelData.keys ?? []).length > 0
                                spacing: 4

                                Repeater {
                                    model: item.modelData.keys ?? []

                                    Rectangle {
                                        required property string modelData

                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.max(26, cap.implicitWidth + 14)
                                        height: 26
                                        radius: 6
                                        color: Theme.surface_container_highest

                                        Label {
                                            id: cap

                                            anchors.centerIn: parent
                                            text: parent.modelData
                                            color: Theme.on_surface_variant
                                            font.pixelSize: 12
                                        }
                                    }
                                }
                            }

                            Icon {
                                visible: name !== ""
                                name: item.modelData.trailingIcon ?? ""
                                size: 18
                                color: Theme.on_surface_variant
                            }

                            Icon {
                                visible: item.modelData.checked ?? false
                                name: "check"
                                size: 20
                                color: Theme.on_secondary_container
                            }

                            // The row's background, moved under the list's
                            // highlight; it follows the row, fading in with it
                            Rectangle {
                                parent: list.contentItem
                                z: -1
                                x: slot.x
                                y: slot.y + slot.gap
                                width: item.width
                                height: item.height
                                topLeftRadius: item.topCorners
                                topRightRadius: item.topCorners
                                bottomLeftRadius: item.bottomCorners
                                bottomRightRadius: item.bottomCorners
                                color: item.modelData.accent ? Theme.tertiary_container : item.hovered && !item.isCurrent ? Theme.surface_container_highest : Theme.surface_container_high
                                opacity: item.opacity
                            }
                        }
                    }
                }

                Label {
                    anchors.verticalCenter: undefined
                    visible: list.count === 0 && root.prompt === ""
                    leftPadding: 4
                    text: "Nothing matches"
                    color: Theme.on_surface_variant
                    font.pixelSize: 14
                    font.weight: Font.Normal
                }

                Loader {
                    width: parent.width
                    active: root.footer !== null
                    visible: active
                    sourceComponent: root.footer
                }
            }
        }
    }
}
