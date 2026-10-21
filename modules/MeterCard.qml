import QtQuick
import ".."
import "../components"

// A meter's items, one row each: its label and how much is left, a bar of
// it, and when it resets. From the Meter it belongs to.
Dropdown {
    id: root

    required property var meter

    menuWidth: 340
    title: meter.title

    Repeater {
        model: root.meter.items

        Rectangle {
            id: row

            required property var modelData
            required property int index
            readonly property bool first: index === 0
            readonly property bool last: index === root.meter.items.length - 1

            width: parent.width
            height: info.implicitHeight + 28
            topLeftRadius: first ? Theme.radius : 3
            topRightRadius: first ? Theme.radius : 3
            bottomLeftRadius: last ? Theme.radius : 3
            bottomRightRadius: last ? Theme.radius : 3
            color: Theme.surface_container_high

            Column {
                id: info

                x: 16
                y: 14
                width: parent.width - 32
                spacing: 6

                Item {
                    width: parent.width
                    height: label.implicitHeight

                    Label {
                        id: label

                        anchors.verticalCenter: undefined
                        text: row.modelData.label
                        color: Theme.on_surface
                        font.pixelSize: 14
                    }

                    Label {
                        anchors.verticalCenter: undefined
                        anchors.right: parent.right
                        text: row.modelData.text
                        color: root.meter.shown === row.modelData ? root.meter.color : Theme.on_surface_variant
                        font.pixelSize: 14
                    }
                }

                LinearProgress {
                    width: parent.width
                    progress: row.modelData.progress
                    thickness: 4
                    trackColor: Qt.rgba(root.meter.color.r, root.meter.color.g, root.meter.color.b, 0.25)
                    color: root.meter.color
                }

                Label {
                    anchors.verticalCenter: undefined
                    visible: text !== ""
                    width: parent.width
                    text: {
                        const r = root.meter.resets(row.modelData);
                        return r ? r.charAt(0).toUpperCase() + r.slice(1) : "";
                    }
                    color: Theme.on_surface_variant
                    font.pixelSize: 12
                    font.weight: Font.Normal
                    elide: Text.ElideRight
                }
            }

            MenuReveal {
                target: row
                shown: root.open
                index: row.index + 1
            }
        }
    }
}
