import QtQuick
import ".."

Text {
    anchors.verticalCenter: parent?.verticalCenter
    color: Theme.on_background
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.weight: Font.Medium

    Behavior on color {
        ColorAnimation {
            duration: Theme.animNormal
        }
    }
}
