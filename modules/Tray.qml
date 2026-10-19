import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import ".."
import "../components"

Pill {
    id: root

    required property var bar

    padding: 15
    spacing: 8
    color: Theme.tertiary_container
    visible: SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items

        IconImage {
            id: trayIcon

            required property SystemTrayItem modelData

            anchors.verticalCenter: parent.verticalCenter
            source: modelData.icon
            implicitSize: 18

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: event => {
                    const item = trayIcon.modelData;
                    if (event.button === Qt.LeftButton && !item.onlyMenu) {
                        item.activate();
                    } else if (item.hasMenu) {
                        const pos = trayIcon.mapToItem(null, 0, trayIcon.height + 8);
                        item.display(root.bar, pos.x, pos.y);
                    }
                }
            }
        }
    }
}
