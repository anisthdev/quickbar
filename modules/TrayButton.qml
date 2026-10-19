import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import ".."
import "../components"

// One tray app as a Material 3 standard icon button: its own icon, no
// container until hovered. Left-click activates, middle-click is the app's
// secondary action, right-click opens its menu as one of ours, and hovering
// shows its tooltip. An app asking for attention gets a small badge. While
// `folded` (hidden in the overflow) it shrinks to nothing; it pops in when
// it first appears and when unfolded.
Item {
    id: root

    required property SystemTrayItem item
    property bool folded: false
    readonly property bool menuOpen: menu.open
    readonly property bool needsAttention: item.status === Status.NeedsAttention

    // While asking for attention, Quickshell swaps in the app's attention
    // icon, which many apps leave empty (a broken placeholder). The badge
    // already says "attention", so keep showing the normal icon, as Android
    // does: the last one seen, or for an app that starts out asking, a
    // theme icon named after it. The title goes first: themes retry a
    // missing name minus its last -part, so an id like "chat-client" can
    // land on an unrelated "chat" icon.
    property string normalIcon: ""
    readonly property string shownIcon: {
        if (!needsAttention)
            return item.icon;
        if (normalIcon !== "")
            return normalIcon;
        return Quickshell.iconPath(item.title.toLowerCase(), item.id.toLowerCase());
    }

    function rememberIcon() {
        if (!needsAttention)
            normalIcon = item.icon;
    }

    Component.onCompleted: rememberIcon()

    Connections {
        target: root.item

        function onIconChanged() {
            root.rememberIcon();
        }
        function onStatusChanged() {
            root.rememberIcon();
        }
    }

    readonly property real size: 30
    // 0 = gone, 1 = fully there; drives width, scale and opacity together
    property real presence: 0

    anchors.verticalCenter: parent?.verticalCenter
    width: size * Math.max(0, presence)
    height: size
    visible: presence > 0

    states: State {
        when: !root.folded
        PropertyChanges {
            root.presence: 1
        }
    }
    transitions: [
        Transition {
            to: ""
            NumberAnimation {
                property: "presence"
                duration: 150
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.emphasizedAccel
            }
        },
        Transition {
            from: ""
            NumberAnimation {
                property: "presence"
                duration: 320
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }
        }
    ]

    Item {
        anchors.centerIn: parent
        width: root.size
        height: root.size
        scale: Math.max(0, root.presence)
        opacity: Math.min(1, Math.max(0, root.presence))

        // State layer: on_tertiary_container at M3's hover/press opacity
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.on_tertiary_container
            opacity: mouse.pressed ? 0.16 : mouse.containsMouse || menu.open ? 0.10 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animFast
                }
            }
        }

        IconImage {
            anchors.centerIn: parent
            source: root.shownIcon
            implicitSize: 18
        }

        Badge {
            x: 20
            y: 4
            shown: root.needsAttention
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: event => {
            if (event.button === Qt.MiddleButton)
                root.item.secondaryActivate();
            else if (event.button === Qt.RightButton || root.item.onlyMenu)
                root.item.hasMenu && menu.toggle();
            else
                root.item.activate();
        }
        onWheel: event => root.item.scroll(event.angleDelta.y, false)
    }

    Tooltip {
        owner: root
        shown: mouse.containsMouse && !menu.open
        text: root.item.tooltipTitle || root.item.title || root.item.id
        description: root.item.tooltipDescription
    }

    TrayMenu {
        id: menu
        owner: root
        item: root.item
    }
}
