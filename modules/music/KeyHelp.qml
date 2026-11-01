import QtQuick
import "../.."
import "../../components"

// The music menu's keys, in a card over it: `bindings` is a list of [keys,
// what they do]. Any key or a click closes it.
Item {
    id: root

    property bool open: false
    property var bindings: []

    signal finished

    function show(list) {
        bindings = list;
        open = true;
        keys.forceActiveFocus();
    }

    function close() {
        open = false;
        finished();
    }

    anchors.fill: parent
    visible: open || scrim.opacity > 0

    Item {
        id: keys

        Keys.onPressed: event => {
            event.accepted = true;
            root.close();
        }
    }

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
        width: Math.min(parent.width - 48, 560)
        height: Math.min(parent.height - 48, content.implicitHeight + 48)
        radius: 28
        color: Qt.alpha(Theme.surface_container_high, 1)
        opacity: scrim.opacity
        scale: 0.94 + 0.06 * scrim.opacity
        clip: true

        Column {
            id: content

            x: 24
            y: 24
            width: parent.width - 48
            spacing: 6

            Label {
                anchors.verticalCenter: undefined
                bottomPadding: 8
                text: "Keys"
                color: Theme.on_surface
                font.pixelSize: 22
                font.weight: Font.Normal
                roundness: Theme.titleRoundness
            }

            Repeater {
                model: root.bindings

                Row {
                    required property var modelData

                    spacing: 16

                    Label {
                        anchors.verticalCenter: undefined
                        width: 150
                        text: modelData[0]
                        color: Theme.primary
                        font.family: Theme.monoFamily
                        font.pixelSize: 13
                    }

                    Label {
                        anchors.verticalCenter: undefined
                        width: content.width - 166
                        text: modelData[1]
                        color: Theme.on_surface_variant
                        font.weight: Font.Normal
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
