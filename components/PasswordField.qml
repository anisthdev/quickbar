import QtQuick
import ".."

// Password entry with a Connect button, for the expanded area of a
// ListItem. Takes keyboard focus while `active`; Enter submits.
Item {
    id: root

    property bool active: false

    signal submitted(string password)

    function submit() {
        if (input.text !== "")
            root.submitted(input.text);
    }

    implicitHeight: 60

    onActiveChanged: {
        input.text = "";
        if (active)
            input.forceActiveFocus();
    }

    Rectangle {
        id: field

        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.right: button.left
        anchors.rightMargin: 8
        anchors.top: parent.top
        height: 44
        radius: Theme.radius
        color: Theme.surface_container_highest
        border.width: input.activeFocus ? 2 : 0
        border.color: Theme.primary

        TextInput {
            id: input

            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            verticalAlignment: TextInput.AlignVCenter
            echoMode: TextInput.Password
            passwordCharacter: "•"
            color: Theme.on_surface
            selectionColor: Theme.primary
            selectedTextColor: Theme.on_primary
            font.family: Theme.fontFamily
            font.pixelSize: 14
            clip: true
            onAccepted: root.submit()
        }

        Label {
            anchors.left: parent.left
            anchors.leftMargin: 14
            visible: input.text === ""
            text: "Password"
            color: Theme.on_surface_variant
            font.weight: Font.Medium
        }
    }

    Rectangle {
        id: button

        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.top: parent.top
        width: buttonLabel.implicitWidth + 32
        height: 44
        radius: Theme.radius
        color: input.text === "" ? Theme.surface_container_highest : Theme.primary

        Behavior on color {
            ColorAnimation {
                duration: Theme.animNormal
            }
        }

        Label {
            id: buttonLabel

            anchors.centerIn: parent
            text: "Connect"
            color: input.text === "" ? Theme.on_surface_variant : Theme.on_primary
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.submit()
        }
    }
}
