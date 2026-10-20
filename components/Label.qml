import QtQuick
import ".."

// Text in the bar's font. The default weight (Medium) renders at
// Theme.bodyWeight through the font's weight axis; any other weight set on
// a Label is used as is.
Text {
    anchors.verticalCenter: parent?.verticalCenter
    color: Theme.on_background
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.weight: Font.Medium

    // Set rather than bound: a binding on one part of `font` that reads
    // another part re-triggers itself
    function applyWeight() {
        const want = font.weight === Font.Medium ? Theme.bodyWeight : font.weight;
        if (font.variableAxes["wght"] !== want)
            font.variableAxes = {
                "wght": want
            };
    }

    Component.onCompleted: applyWeight()
    onFontChanged: applyWeight()

    Behavior on color {
        ColorAnimation {
            duration: Theme.animNormal
        }
    }
}
