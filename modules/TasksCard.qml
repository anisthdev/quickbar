import Quickshell
import QtQuick
import ".."
import "../components"

// The to-do list as the tasks count's dropdown (see Tasks), as the
// calendar is the time's: the tasks (Todo, in ~/Notes/todo.md) as a grouped
// list, the ones left first, then the done ones under a heading with a
// button to clear them, and a field under it all to add more. A click on a
// task ticks it or unticks it; its × deletes it. Opened with nothing on the
// list, the field has the keys.
//
// Keys: j/k (gg/G, Ctrl+d/u) move, Enter or Space ticks a task or unticks
// it, d deletes it, c clears the done ones, a or i goes to the field:
// type the task and Enter, the field staying for the next one, Esc back to
// the list. q or Esc closes.
Dropdown {
    id: root

    // The ones left first, each kept in its place in the file otherwise
    readonly property var entries: Todo.tasks.filter(t => !t.done).concat(Todo.tasks.filter(t => t.done)).map(t => Object.assign({
                key: `${t.line}:${t.text}`
            }, t))
    readonly property var current: entries[cursor.currentIndex] ?? null
    property bool adding: false

    function add(on) {
        adding = on;
        if (!on)
            takeKeys();
    }

    // Whether a row starts or ends its group: the ones left, or the done ones
    function startsGroup(i) {
        return i === 0 || entries[i - 1].done !== entries[i].done;
    }
    function endsGroup(i) {
        return i === entries.length - 1 || entries[i + 1].done !== entries[i].done;
    }

    menuWidth: 340
    title: Todo.left > 0 ? `To do · ${Todo.left} left` : "To do"
    smoothResize: true

    onOpenChanged: {
        cursor.currentIndex = -1;
        add(open && Todo.tasks.length === 0);
    }
    keyHandler: event => {
        if (keys.handle(event))
            return true;
        if (event.modifiers & Qt.ControlModifier)
            return false;
        switch (event.key) {
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            if (current)
                Todo.toggle(current);
            return true;
        case Qt.Key_D:
            if (current)
                Todo.remove(current);
            return true;
        case Qt.Key_C:
            Todo.clearDone();
            return true;
        case Qt.Key_A:
        case Qt.Key_I:
            add(true);
            return true;
        }
        return false;
    }

    RowCursor {
        id: cursor
        count: root.entries.length
        // Keep the keys' row in view
        onCurrentIndexChanged: if (currentIndex >= 0)
            list.positionViewAtIndex(currentIndex, ListView.Contain)
    }

    ListKeys {
        id: keys
        list: cursor
    }

    ListView {
        id: list

        visible: count > 0
        width: parent.width
        // Eight or so rows before it scrolls
        height: Math.min(contentHeight, 420)
        spacing: 2
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        model: ScriptModel {
            values: root.entries
            objectProp: "key"
        }

        // A task's row, with the done ones' heading over the first of them
        delegate: Item {
            id: slot

            required property var modelData
            required property int index
            readonly property bool heading: modelData.done && root.startsGroup(index)

            width: list.width
            height: row.height + (heading ? doneHeading.height : 0)

            Item {
                id: doneHeading

                visible: slot.heading
                width: parent.width
                height: 44

                Label {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: undefined
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    text: "Done"
                    color: Theme.on_surface_variant
                    font.pixelSize: 13
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    width: clearLabel.implicitWidth + 24
                    height: 28
                    radius: Theme.radius
                    color: clearMouse.containsMouse ? Theme.surface_container_highest : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.animFast
                        }
                    }

                    Label {
                        id: clearLabel

                        anchors.centerIn: parent
                        text: "Clear"
                        color: Theme.primary
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: clearMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Todo.clearDone()
                    }
                }
            }

            ListItem {
                id: row

                y: slot.heading ? doneHeading.height : 0
                icon: slot.modelData.done ? "check_box" : "check_box_outline_blank"
                text: slot.modelData.text
                first: root.startsGroup(slot.index)
                last: root.endsGroup(slot.index)
                clickable: true
                highlighted: cursor.currentIndex === slot.index
                shown: root.open
                revealIndex: slot.index + 1
                onClicked: Todo.toggle(slot.modelData)

                IconButton {
                    implicitWidth: 36
                    implicitHeight: 36
                    icon: "close"
                    iconSize: 16
                    color: Theme.on_surface_variant
                    onClicked: Todo.remove(slot.modelData)
                }
            }
        }
    }

    Label {
        anchors.verticalCenter: undefined
        visible: Todo.tasks.length === 0
        leftPadding: 8
        bottomPadding: 6
        text: "Nothing to do"
        color: Theme.on_surface_variant
        font.pixelSize: 14
        font.weight: Font.Normal
    }

    // Room over the field
    Item {
        width: 1
        height: 6
    }

    EntryField {
        id: field

        width: parent.width
        inset: 0
        active: root.adding
        secret: false
        placeholder: "A new task…"
        buttonText: "Add"
        // Stays for the next one
        onSubmitted: text => {
            Todo.add(text);
            field.clear();
        }
        // Back to the list, or out if there's none
        onCancelled: {
            if (Todo.tasks.length === 0)
                root.open = false;
            root.add(false);
        }

        MenuReveal {
            target: field
            shown: root.open
            index: root.entries.length + 1
        }
    }
}
