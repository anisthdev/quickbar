import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import ".."
import "../components"

Pill {
    id: root

    readonly property var toplevel: ToplevelManager.activeToplevel
    // activeToplevel keeps the last focused window around, so an empty
    // workspace is detected through Hyprland instead
    readonly property bool hasWindow: toplevel !== null && HyprState.windows(HyprState.focusedId) > 0
    readonly property string appIcon: {
        if (!toplevel)
            return "";
        const entry = DesktopEntries.heuristicLookup(toplevel.appId);
        return Quickshell.iconPath(entry?.icon ?? toplevel.appId, true);
    }

    padding: 20
    spacing: 8
    opacity: hasWindow ? 1 : 0
    scale: hasWindow ? 1 : 0.9

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.animNormal
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.animNormal
            easing.type: Easing.OutCubic
        }
    }

    IconImage {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.appIcon !== ""
        source: root.appIcon
        implicitSize: 18
    }

    Label {
        text: root.toplevel?.title ?? ""
        elide: Text.ElideRight
        width: Math.min(implicitWidth, 420)
    }
}
