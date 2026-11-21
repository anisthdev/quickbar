import QtQuick
import "../.."
import "../../components"

// The question before deleting a title, in a card over the video menu:
// what it is, whether it's been seen (how much hasn't, as a warning), and
// that it goes to the trash (its torrent, if seeding, removed). y or Enter deletes;
// n, Esc or a click outside keeps it.
Item {
    id: root

    property bool open: false
    property string title
    property string unseen
    // Not seen to the end: the line about it is a warning
    property bool warn: false
    property var onConfirm: null

    signal finished

    function ask(name, why, confirm, warning) {
        title = name;
        unseen = why;
        warn = !!warning;
        onConfirm = confirm;
        open = true;
        keys.forceActiveFocus();
    }

    function close(confirmed) {
        open = false;
        const confirm = onConfirm;
        onConfirm = null;
        finished();
        if (confirmed && confirm)
            confirm();
    }

    anchors.fill: parent
    visible: open || scrim.opacity > 0

    Item {
        id: keys

        Keys.onPressed: event => {
            event.accepted = true;
            if (event.text === "y" || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                root.close(true);
            else if (event.text === "n" || event.text === "q" || event.key === Qt.Key_Escape)
                root.close(false);
        }
    }

    Rectangle {
        id: scrim

        anchors.fill: parent
        radius: Theme.cardRadius
        color: Qt.rgba(0, 0, 0, 0.5)
        opacity: root.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animFast
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close(false)
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 440)
        height: content.implicitHeight + 48
        radius: 28
        color: Qt.alpha(Theme.surface_container_high, 1)
        opacity: scrim.opacity
        scale: 0.94 + 0.06 * scrim.opacity

        // Swallow clicks on the card
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: content

            x: 24
            y: 24
            width: parent.width - 48
            spacing: 10

            Icon {
                anchors.verticalCenter: undefined
                anchors.horizontalCenter: parent.horizontalCenter
                name: "delete"
                size: 26
                color: Theme.error
            }

            Label {
                anchors.verticalCenter: undefined
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: `Delete ${root.title}?`
                color: Theme.on_surface
                font.pixelSize: 20
                font.weight: Theme.titleWeight
                roundness: Theme.titleRoundness
                wrapMode: Text.WordWrap
            }

            Label {
                anchors.verticalCenter: undefined
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.unseen
                color: root.warn ? Theme.error : Theme.on_surface_variant
                font.pixelSize: 13
                font.weight: root.warn ? Font.DemiBold : Font.Normal
                wrapMode: Text.WordWrap
            }

            Label {
                anchors.verticalCenter: undefined
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "Its files go to the trash, and a torrent seeding them is removed."
                color: Theme.on_surface_variant
                font.pixelSize: 13
                font.weight: Font.Normal
                wrapMode: Text.WordWrap
                lineHeight: 1.2
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 10
                spacing: 10

                Repeater {
                    model: [
                        {
                            label: "Keep it",
                            key: "n",
                            yes: false
                        },
                        {
                            label: "Delete",
                            key: "y",
                            yes: true
                        }
                    ]

                    Rectangle {
                        id: button

                        required property var modelData

                        width: buttonRow.implicitWidth + 40
                        height: 40
                        radius: 20
                        color: modelData.yes ? (buttonMouse.containsMouse ? Qt.lighter(Theme.error, 1.08) : Theme.error) : (buttonMouse.containsMouse ? Qt.alpha(Theme.on_surface, 0.14) : Qt.alpha(Theme.on_surface, 0.08))

                        Row {
                            id: buttonRow

                            anchors.centerIn: parent
                            spacing: 8

                            Label {
                                text: button.modelData.label
                                color: button.modelData.yes ? Theme.on_error : Theme.on_surface
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }

                            Label {
                                text: button.modelData.key
                                color: button.modelData.yes ? Theme.on_error : Theme.on_surface_variant
                                opacity: 0.6
                                font.family: Theme.monoFamily
                                font.pixelSize: 12
                            }
                        }

                        MouseArea {
                            id: buttonMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.close(button.modelData.yes)
                        }
                    }
                }
            }
        }
    }
}
