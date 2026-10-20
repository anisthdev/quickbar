import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."

// A menu in the rofi menus' place and shape: bottom centre, a title, a
// filter field and a grouped list (ListItem rows) of entries with app icons. Typing filters, Up/Down
// pick, Enter or a click runs the pick (`activated`), Esc or a click outside
// closes. It springs open upwards and folds back down, by shape only.
//
// entries: [{ label, icon }, …] plus whatever the owner needs; icon is a
// theme icon name or a path.
Scope {
    id: root

    property string title
    property string placeholder: "Filter…"
    property var entries: []
    property bool open: false

    signal activated(var entry)

    readonly property var shown: {
        const q = field.text.trim().toLowerCase();
        return q === "" ? entries : entries.filter(e => e.label.toLowerCase().includes(q));
    }

    function show() {
        field.text = "";
        list.currentIndex = 0;
        open = true;
        field.forceActiveFocus();
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

            property real fullHeight: content.y + content.implicitHeight + 20

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            width: 500
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
                    // rofi's 20 pt
                    font.pixelSize: 26
                    font.weight: Font.Bold
                }

                Rectangle {
                    width: parent.width
                    height: 46
                    radius: Theme.radius
                    color: Theme.surface_container_highest

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

                        Keys.onPressed: event => {
                            switch (event.key) {
                            case Qt.Key_Escape:
                                root.hide();
                                break;
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                                root.run(list.currentIndex);
                                break;
                            case Qt.Key_Down:
                            case Qt.Key_Tab:
                                list.incrementCurrentIndex();
                                break;
                            case Qt.Key_Up:
                            case Qt.Key_Backtab:
                                list.decrementCurrentIndex();
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

                    visible: count > 0
                    width: parent.width
                    height: count * rowHeight + Math.max(0, count - 1) * spacing
                    spacing: 2
                    interactive: false
                    model: root.shown

                    // The grouped list rows of the other menus
                    delegate: ListItem {
                        required property var modelData
                        required property int index

                        width: list.width
                        rowHeight: list.rowHeight
                        image: {
                            const name = modelData.icon ?? "";
                            return name.startsWith("/") ? `file://${name}` : Quickshell.iconPath(name, true);
                        }
                        imageSize: 32
                        text: modelData.label
                        first: index === 0
                        last: index === list.count - 1
                        clickable: true
                        highlighted: ListView.isCurrentItem
                        shown: root.open
                        revealIndex: index
                        onClicked: root.run(index)
                        onHoveredChanged: if (hovered)
                            list.currentIndex = index
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
