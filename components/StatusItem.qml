import QtQuick
import ".."

// One button of the status group, in the Material 3 Expressive connected
// button group style: the group's outer corners match the bar's, the seams
// between buttons are tight. A button fills with the primary container while
// its thing is on, and rounds all its corners while its menu is open.
Pill {
    id: root

    property alias icon: icon.name
    property alias text: label.text
    property alias iconSize: icon.size
    // Connected, powered, unmuted…
    property bool active: true
    // Its menu is showing
    property bool open: false
    // Ends of the group, which get the round outer corners
    property bool first: false
    property bool last: false

    readonly property real round: 8
    readonly property real seam: 4
    property real leftCorners: open || first ? round : seam
    property real rightCorners: open || last ? round : seam

    readonly property color foreground: active ? Theme.on_primary_container : Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.6)
    readonly property color base: active ? Theme.primary_container : Theme.surface_container_high

    padding: 14
    implicitHeight: Theme.barHeight - 10
    topLeftRadius: leftCorners
    bottomLeftRadius: leftCorners
    topRightRadius: rightCorners
    bottomRightRadius: rightCorners
    // Hover and press state layers, tinted with the content colour
    color: Qt.tint(base, Qt.rgba(foreground.r, foreground.g, foreground.b, pressed ? 0.12 : hovered || open ? 0.08 : 0))
    clickable: true
    // Tinted into color above instead, so it can stay on with the menu open
    stateLayer: false

    Behavior on leftCorners {
        NumberAnimation {
            duration: Theme.animNormal
            easing.type: Easing.OutBack
        }
    }
    Behavior on rightCorners {
        NumberAnimation {
            duration: Theme.animNormal
            easing.type: Easing.OutBack
        }
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
