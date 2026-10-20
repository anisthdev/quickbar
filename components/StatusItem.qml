import QtQuick
import ".."

// One button of the status pill: an icon, and its details (the network's
// name…) while they're shown. Dimmed while its thing is off; a state layer
// on hover, kept while its menu is open. Middle-clicking any of them shows
// or hides the details of all.
Pill {
    id: root

    property alias icon: icon.name
    property alias text: label.text
    property alias iconSize: icon.size
    // Connected, powered, unmuted…
    property bool active: true
    // Its menu is showing
    property bool open: false

    readonly property color foreground: active ? Theme.on_surface : Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.45)

    padding: label.visible ? 12 : 9
    implicitHeight: Theme.barHeight - 10
    radius: 8
    color: Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, pressed ? 0.12 : hovered || open ? 0.08 : 0)
    clickable: true
    // Drawn as the colour above instead, so it can stay on with the menu open
    stateLayer: false
    onClicked: event => {
        if (event.button === Qt.MiddleButton)
            Settings.showStatusDetails = !Settings.showStatusDetails;
    }

    Icon {
        id: icon
        color: root.foreground
    }

    Label {
        id: label
        color: root.foreground
        font.weight: Font.Medium
        visible: text !== ""
    }
}
