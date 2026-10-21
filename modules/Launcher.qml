import QtQuick
import ".."
import "../components"
import "../components/MaterialShapes.js" as MaterialShapes

// The app launcher's button, tonal: the bar's one standing accent, in
// Material 3's 9-sided cookie, which turns a scallop on hover.
Item {
    id: root

    required property var apps

    implicitWidth: Theme.barHeight
    implicitHeight: Theme.barHeight

    Item {
        anchors.fill: parent
        rotation: mouse.containsMouse ? 40 : 0

        Behavior on rotation {
            NumberAnimation {
                duration: 450
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.emphasizedDecel
            }
        }

        GlyphShape {
            d: MaterialShapes.shapes.Cookie9Sided
            unit: root.width / 100
            fill: Theme.primary_container
        }

        // Material hover and press state layer, in the shape
        GlyphShape {
            d: MaterialShapes.shapes.Cookie9Sided
            unit: root.width / 100
            fill: Theme.on_primary_container
            opacity: mouse.pressed ? 0.12 : mouse.containsMouse ? 0.08 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animFast
                }
            }
        }
    }

    Icon {
        anchors.centerIn: parent
        name: "archlinux"
        size: 16
        color: Theme.on_primary_container
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.apps.toggle()
    }
}
