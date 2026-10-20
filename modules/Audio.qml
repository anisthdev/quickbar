import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import ".."
import "../components"

// Icon, then the output's name and volume level when the status details
// are on: click for the output picker, scroll for volume, middle-click to
// show or hide the details, right-click for the control panel's input page.
StatusItem {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool bluetooth: /bluez/i.test(sink?.name ?? "")

    // Android's media volume icon: a music note, with a Bluetooth mark for
    // Bluetooth audio
    icon: (bluetooth ? "volume_bt" : "volume") + (muted ? "_mute" : "")
    iconSize: 18
    active: !muted
    open: menu.open
    readonly property string sinkName: sink?.description || sink?.nickname || sink?.name || ""

    readonly property int level: Math.round(volume * 100)

    text: !Settings.showStatusDetails ? "" : sinkName ? `${sinkName}  ${level}` : String(level)

    onClicked: event => {
        if (event.button === Qt.MiddleButton)
            return;
        if (event.button === Qt.RightButton)
            Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/menus/control-panel-script", "--page", "audio-inputs"]);
        else
            menu.toggle();
    }

    onScrolled: event => {
        if (!sink?.audio)
            return;
        const step = event.angleDelta.y > 0 ? 0.01 : -0.01;
        sink.audio.volume = Math.max(0, Math.min(1, volume + step));
    }

    // Volume and mute are only populated for tracked nodes
    PwObjectTracker {
        objects: [root.sink]
    }

    AudioMenu {
        id: menu
        owner: root
    }

    Tooltip {
        owner: root
        // What the details would show, when they're hidden
        shown: root.hovered && !menu.open && !Settings.showStatusDetails
        text: root.sinkName ? `${root.sinkName} · ${root.level}%` : `${root.level}%`
    }

    // `qs -p <dir> ipc call audio toggle`, e.g. from a Hyprland keybind
    IpcHandler {
        target: "audio"

        function toggle(): void {
            menu.toggle();
        }
    }
}
