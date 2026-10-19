import QtQuick
import ".."

// Three little bars that bounce while music plays and settle when paused.
Row {
    id: root

    property bool playing: false
    property color color: Theme.on_surface

    anchors.verticalCenter: parent?.verticalCenter
    spacing: 2
    height: 12

    Repeater {
        model: [520, 380, 640]

        Rectangle {
            id: bar

            required property int modelData
            property real level: 0.3

            anchors.bottom: parent.bottom
            width: 3
            height: Math.max(width, root.height * level)
            radius: width / 2
            color: root.color

            SequentialAnimation on level {
                running: root.playing
                loops: Animation.Infinite
                NumberAnimation {
                    to: 1
                    duration: bar.modelData / 2
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 0.25
                    duration: bar.modelData / 2
                    easing.type: Easing.InOutSine
                }
            }

            // Settle to a low bar when paused
            Binding on level {
                when: !root.playing
                value: 0.3
            }
        }
    }
}
