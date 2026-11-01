import QtQuick
import "../.."
import "../../components"

// A playlist to add to, or a name to save the queue as, in a card over the
// music menu's page. Typing filters the playlists; with what's typed not a
// playlist's name, a row offers to make it (adding) or it's the name
// (saving). Up/Down (Ctrl+j/k, Tab) move, Enter picks, Esc cancels. It takes
// the keyboard while open.
Item {
    id: root

    property bool open: false
    // "add" (files to a playlist) or "save" (the queue)
    property string mode: "add"
    // What's being added, for the title
    property string what
    property var names: []
    property int index: 0
    property var done: null

    signal finished

    readonly property string typed: field.text.trim()
    readonly property var rows: {
        if (mode === "save")
            return [];
        const q = typed.toLowerCase();
        const shown = names.filter(n => n.toLowerCase().includes(q)).map(n => ({
                    name: n,
                    fresh: false
                }));
        if (typed !== "" && !names.some(n => n.toLowerCase() === q))
            shown.unshift({
                name: typed,
                fresh: true
            });
        return shown;
    }

    // Asks; `picked` gets the playlist's name
    function ask(mode, what, names, picked) {
        root.mode = mode;
        root.what = what;
        root.names = names;
        done = picked;
        field.text = "";
        index = 0;
        open = true;
        field.forceActiveFocus();
    }

    function close() {
        open = false;
        done = null;
        finished();
    }

    function confirm() {
        const name = mode === "save" ? typed : rows[index]?.name ?? "";
        if (name === "")
            return;
        const action = done;
        close();
        action?.(name);
    }

    onRowsChanged: index = Math.min(index, Math.max(0, rows.length - 1))

    anchors.fill: parent
    visible: open || scrim.opacity > 0

    Rectangle {
        id: scrim

        anchors.fill: parent
        radius: Theme.cardRadius
        color: Qt.rgba(0, 0, 0, 0.45)
        opacity: root.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animFast
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 380)
        height: content.implicitHeight + 40
        radius: 28
        color: Qt.alpha(Theme.surface_container_high, 1)
        opacity: scrim.opacity
        scale: 0.94 + 0.06 * scrim.opacity

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: content

            x: 20
            y: 20
            width: parent.width - 40
            spacing: 12

            Label {
                anchors.verticalCenter: undefined
                leftPadding: 4
                width: parent.width
                text: root.mode === "save" ? "Save the queue as" : `Add ${root.what} to`
                color: Theme.on_surface
                font.pixelSize: 20
                font.weight: Font.Normal
                roundness: Theme.titleRoundness
                elide: Text.ElideRight
            }

            Rectangle {
                width: parent.width
                height: 44
                radius: height / 2
                color: Theme.surface_container_highest

                TextInput {
                    id: field

                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.on_surface
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.on_primary
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    clip: true
                    Keys.onPressed: event => {
                        const ctrl = event.modifiers & Qt.ControlModifier;
                        event.accepted = true;
                        if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || ctrl && event.key === Qt.Key_J)
                            root.index = Math.min(root.rows.length - 1, root.index + 1);
                        else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || ctrl && event.key === Qt.Key_K)
                            root.index = Math.max(0, root.index - 1);
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                            root.confirm();
                        else if (event.key === Qt.Key_Escape)
                            root.close();
                        else
                            event.accepted = false;
                    }

                    Label {
                        anchors.verticalCenter: undefined
                        visible: field.text === ""
                        text: root.mode === "save" ? "A name for the playlist" : "Find a playlist, or name a new one"
                        color: Theme.on_surface_variant
                        font: field.font
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 2
                visible: root.rows.length > 0

                Repeater {
                    model: root.rows.slice(0, 6)

                    Rectangle {
                        id: row

                        required property var modelData
                        required property int index
                        readonly property bool current: index === root.index

                        width: parent.width
                        height: 40
                        radius: 10
                        color: current ? Theme.secondary_container : "transparent"

                        Icon {
                            x: 12
                            name: row.modelData.fresh ? "add" : "checklist"
                            size: 18
                            color: row.current ? Theme.on_secondary_container : Theme.on_surface_variant
                        }

                        Label {
                            x: 42
                            width: parent.width - 54
                            text: row.modelData.fresh ? `New playlist “${row.modelData.name}”` : row.modelData.name
                            color: row.current ? Theme.on_secondary_container : Theme.on_surface
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.index = row.index
                            onClicked: root.confirm()
                        }
                    }
                }
            }

            Label {
                anchors.verticalCenter: undefined
                leftPadding: 4
                visible: root.mode === "add" && root.rows.length === 0
                text: "No playlists yet: type a name to make one"
                color: Theme.on_surface_variant
                font.weight: Font.Normal
            }
        }
    }
}
