import QtQuick
import ".."

// Staggered entrance for one menu entry: when `shown` turns on, `target`
// waits its turn (by `index`), then fades in while sliding down into place.
// When `shown` turns off, it fades out at once with the rest of the menu.
Item {
    id: root

    required property Item target
    required property bool shown
    property int index: 0

    visible: false

    Translate {
        id: slide
        y: -10
    }

    Component.onCompleted: {
        target.transform = slide;
        target.opacity = shown ? 1 : 0;
        if (shown)
            slide.y = 0;
    }

    onShownChanged: {
        enter.stop();
        leave.stop();
        if (shown) {
            target.opacity = 0;
            slide.y = -10;
            enter.start();
        } else {
            leave.start();
        }
    }

    SequentialAnimation {
        id: enter

        PauseAnimation {
            duration: 60 + root.index * 35
        }
        ParallelAnimation {
            NumberAnimation {
                target: root.target
                property: "opacity"
                to: 1
                duration: 200
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: slide
                property: "y"
                to: 0
                duration: 400
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.emphasizedDecel
            }
        }
    }

    NumberAnimation {
        id: leave

        target: root.target
        property: "opacity"
        to: 0
        duration: 90
    }
}
