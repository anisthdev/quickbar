import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

// The mic mute key's LED, lit while the default mic is muted, however it
// was muted (the key, the control panel, an app). The kernel would light
// it from ALSA's controls, which PipeWire's mute never touches, so this
// writes the LED itself; dotfiles' 90-privacy-keys.rules lets it.
Scope {
    id: root

    readonly property string led: "/sys/class/leds/platform::micmute/brightness"
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool muted: source?.audio?.muted ?? false

    function sync() {
        write.command = ["sh", "-c", 'echo "$1" > "$2"', "sh", muted ? "1" : "0", led];
        write.running = true;
    }

    onMutedChanged: sync()
    Component.onCompleted: sync()

    PwObjectTracker {
        objects: [root.source]
    }

    Process {
        id: write
    }
}
