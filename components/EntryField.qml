import QtQuick
import ".."

// A text field with a button beside it: the Wi-Fi password, a reply to a
// notification. Takes keyboard focus while `active`; Enter or the button
// submits, Escape cancels.
Item {
    id: root

    property bool active: false
    property string placeholder: "Password"
    property string buttonText: "Connect"
    // Dots instead of the text
    property bool secret: true
    // Room either side, e.g. to line up with a list row's content
    property real inset: 10

    signal submitted(string text)
    signal cancelled

    // Empty again, e.g. for the next of several entries
    function clear() {
        input.text = "";
    }

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
        anchors.leftMargin: root.inset
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
            echoMode: root.secret ? TextInput.Password : TextInput.Normal
            passwordCharacter: "•"
            color: Theme.on_surface
            selectionColor: Theme.primary
            selectedTextColor: Theme.on_primary
            font.family: Theme.fontFamily
            font.pixelSize: 14
            clip: true
            onAccepted: root.submit()
            Keys.onEscapePressed: root.cancelled()
        }

        Label {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 14
            elide: Text.ElideRight
            visible: input.text === ""
            text: root.placeholder
            color: Theme.on_surface_variant
            font.weight: Font.Medium
        }
    }

    Rectangle {
        id: button

        anchors.right: parent.right
        anchors.rightMargin: root.inset
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
            text: root.buttonText
            color: input.text === "" ? Theme.on_surface_variant : Theme.on_primary
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.submit()
        }
    }
}
