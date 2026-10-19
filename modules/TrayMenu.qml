import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import ".."
import "../components"

// A tray app's own menu, drawn as one of our Material 3 menus instead of
// the app's toolkit style. Separators split the entries into grouped
// lists; check and radio entries show a check mark when on. An entry with
// a submenu slides the menu across to it, with a back row on top.
Dropdown {
    id: root

    required property SystemTrayItem item

    // Submenu entries opened so far; empty at the app's top-level menu
    property var path: []
    readonly property var current: path.length > 0 ? path[path.length - 1] : null
    // Each level needs its own opener, kept open while a submenu shows:
    // closing a menu destroys its entries, including the submenu's own
    property var currentOpener: rootOpener
    readonly property var entries: currentOpener.children.values

    // Whether an entry starts or ends a group (separators split groups)
    function startsGroup(i) {
        return i === 0 || entries[i - 1].isSeparator;
    }
    function endsGroup(i) {
        return i === entries.length - 1 || entries[i + 1].isSeparator;
    }

    function enter(entry) {
        path = path.concat([entry]);
        slide.from = 28;
        pageAnim.restart();
    }
    function back() {
        path = path.slice(0, -1);
        slide.from = -28;
        pageAnim.restart();
    }

    menuWidth: 240
    // Compact, like a context menu, unlike the quick settings style menus
    sidePadding: 6
    endPadding: 6
    cornerRadius: 16
    smoothResize: true

    onOpenChanged: if (open)
        path = []

    QsMenuOpener {
        id: rootOpener
        menu: root.item.menu
    }

    Instantiator {
        id: subOpeners

        // ScriptModel adds and removes openers one by one; a plain array
        // would rebuild them all, closing the levels in between
        model: ScriptModel {
            values: root.path
        }

        QsMenuOpener {
            required property QsMenuEntry modelData
            menu: modelData
        }

        onObjectAdded: (index, object) => {
            if (index === root.path.length - 1)
                root.currentOpener = object;
        }
        onObjectRemoved: (index, object) => {
            if (object === root.currentOpener)
                root.currentOpener = root.path.length > 0 ? objectAt(root.path.length - 1) : rootOpener;
        }
    }

    // Slides a new page in from the side it came from
    ParallelAnimation {
        id: pageAnim

        NumberAnimation {
            id: slide

            target: page
            property: "x"
            to: 0
            duration: 250
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasizedDecel
        }
        NumberAnimation {
            target: page
            property: "opacity"
            from: 0
            to: 1
            duration: 150
        }
    }

    Column {
        id: page

        width: parent.width
        spacing: 2

        // Top level: the app's name. In a submenu: a back row named after it.
        Rectangle {
            id: heading

            width: parent.width
            height: 28
            radius: 14
            color: root.current && backMouse.containsMouse ? Theme.surface_container_highest : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Theme.animFast
                }
            }

            Icon {
                id: backIcon

                x: 10
                visible: root.current !== null
                name: "chevron"
                size: 14
                color: Theme.on_surface
            }

            Label {
                anchors.left: backIcon.visible ? backIcon.right : parent.left
                anchors.leftMargin: backIcon.visible ? 8 : 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                text: root.current ? root.current.text : root.item.tooltipTitle || root.item.title || root.item.id
                color: root.current ? Theme.on_surface : Theme.on_surface_variant
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            MouseArea {
                id: backMouse

                anchors.fill: parent
                enabled: root.current !== null
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.back()
            }

            MenuReveal {
                target: heading
                shown: root.open
            }
        }

        Repeater {
            model: root.entries

            // A row, or for a separator, the gap between two groups
            Item {
                id: entry

                required property QsMenuEntry modelData
                required property int index
                readonly property bool checkable: modelData.buttonType !== QsMenuButtonType.None

                width: parent.width
                height: modelData.isSeparator ? 4 : row.height
                // Dimmed here, not on the row, whose opacity MenuReveal animates
                opacity: modelData.enabled ? 1 : 0.38

                ListItem {
                    id: row

                    visible: !entry.modelData.isSeparator
                    rowHeight: 36
                    outerRadius: 12
                    image: entry.modelData.icon
                    text: entry.modelData.text
                    first: root.startsGroup(entry.index)
                    last: root.endsGroup(entry.index)
                    clickable: entry.modelData.enabled
                    shown: root.open
                    revealIndex: entry.index + 1
                    onClicked: {
                        if (entry.modelData.hasChildren) {
                            root.enter(entry.modelData);
                        } else {
                            entry.modelData.triggered();
                            root.open = false;
                        }
                    }

                    Icon {
                        visible: entry.checkable && entry.modelData.checkState === Qt.Checked
                        name: "check"
                        size: 20
                        color: Theme.primary
                    }

                    // Submenu arrow: the back chevron turned around
                    Icon {
                        visible: entry.modelData.hasChildren
                        name: "chevron"
                        size: 14
                        rotation: 180
                        color: Theme.on_surface_variant
                    }
                }
            }
        }
    }
}
