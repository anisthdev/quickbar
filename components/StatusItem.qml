import QtQuick
import ".."
import "MaterialShapes.js" as MaterialShapes

// One button of the status pill: an icon, and its details (the network's
// name…) while they're shown. Dimmed while its thing is off; a state layer
// on hover, kept while its menu is open: one of Material 3's expressive
// shapes, turning a little, around the icon alone, or the button's rounded
// rectangle around its details. Middle-clicking any of them shows or hides
// the details of all.
Pill {
    id: root

    property alias icon: icon.name
    property alias text: label.text
    property alias iconSize: icon.size
    // Connected, powered, unmuted…
    property bool active: true
    // Its menu is showing
    property bool open: false
    // The state layer's shape, from MaterialShapes
    property string shape: "Cookie9Sided"

    readonly property color foreground: active ? Theme.on_surface : Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.45)
    readonly property real stateOpacity: pressed ? 0.12 : hovered || open ? 0.08 : 0

    padding: label.visible ? 12 : 9
    implicitHeight: Theme.barHeight - 10
    radius: 8
    color: Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, label.visible ? stateOpacity : 0)

    underlay: Item {
        anchors.centerIn: parent
        width: parent.height
        height: parent.height
        visible: !label.visible
        rotation: root.hovered || root.open ? 40 : 0

        Behavior on rotation {
            NumberAnimation {
                duration: 450
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.emphasizedDecel
            }
        }

        GlyphShape {
            d: MaterialShapes.shapes[root.shape]
            unit: parent.width / 100
            fill: Theme.on_surface
            opacity: root.stateOpacity

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animFast
                }
            }
        }
    }
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
