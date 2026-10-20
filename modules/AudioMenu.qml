import Quickshell.Services.Pipewire
import QtQuick
import ".."
import "../components"

// Volume slider for the current sink, then an output picker: every
// PipeWire sink, with the current one highlighted. Picking a row makes it
// the default sink.
//
// Keys: h/l the volume by 5% (H/L by 1%), m mutes, j/k/gg/G move through
// the outputs, Enter or Space picks one.
Dropdown {
    id: root

    // Sinks waybar also hid
    readonly property var ignored: ["easyeffects_sink"]
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio && !ignored.includes(n.name))

    function deviceIcon(node) {
        const props = node.properties ?? {};
        const text = `${node.name} ${node.description}`;
        if (/bluez/i.test(node.name))
            return "device_headphones";
        if (/hdmi|displayport|monitor/i.test(text))
            return "device_display";
        if (props["device.form-factor"] === "internal" || /laptop/i.test(text))
            return "device_laptop";
        return "device_speaker";
    }

    function nudge(by) {
        const audio = Pipewire.defaultAudioSink?.audio;
        if (audio)
            audio.volume = Math.max(0, Math.min(1, Math.round((audio.volume + by) * 100) / 100));
    }

    menuWidth: 340
    title: "Sound"
    onOpenChanged: if (open)
        cursor.currentIndex = -1
    keyHandler: event => {
        if (keys.handle(event))
            return true;
        const big = !(event.modifiers & Qt.ShiftModifier) && event.text !== "H" && event.text !== "L";
        switch (event.key) {
        case Qt.Key_H:
        case Qt.Key_Left:
            nudge(big ? -0.05 : -0.01);
            return true;
        case Qt.Key_L:
        case Qt.Key_Right:
            nudge(big ? 0.05 : 0.01);
            return true;
        case Qt.Key_M:
            {
                const audio = Pipewire.defaultAudioSink?.audio;
                if (audio)
                    audio.muted = !audio.muted;
                return true;
            }
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            if (sinks[cursor.currentIndex])
                Pipewire.preferredDefaultAudioSink = sinks[cursor.currentIndex];
            return true;
        }
        return false;
    }

    RowCursor {
        id: cursor
        count: root.sinks.length
    }

    ListKeys {
        id: keys
        list: cursor
    }

    Slider {
        id: slider

        readonly property PwNode sink: Pipewire.defaultAudioSink
        readonly property bool bluetooth: /bluez/i.test(sink?.name ?? "")
        readonly property bool muted: sink?.audio?.muted ?? false

        width: parent.width
        value: sink?.audio?.volume ?? 0
        dimmed: muted
        icon: (bluetooth ? "volume_bt" : "volume") + (muted ? "_mute" : "")
        onMoved: v => {
            if (sink?.audio)
                sink.audio.volume = v;
        }
        onIconClicked: {
            if (sink?.audio)
                sink.audio.muted = !muted;
        }

        MenuReveal {
            target: slider
            shown: root.open
        }
    }

    Label {
        id: heading

        anchors.verticalCenter: undefined
        leftPadding: 12
        topPadding: 12
        bottomPadding: 6
        text: "Sound output"
        color: Theme.on_surface_variant
        font.pixelSize: 13

        MenuReveal {
            target: heading
            shown: root.open
            index: 1
        }
    }

    Repeater {
        model: root.sinks

        ListItem {
            id: item

            required property PwNode modelData
            required property int index

            icon: root.deviceIcon(modelData)
            text: modelData.description || modelData.nickname || modelData.name
            first: index === 0
            last: index === root.sinks.length - 1
            selected: Pipewire.defaultAudioSink === modelData
            highlighted: cursor.currentIndex === index
            clickable: true
            shown: root.open
            revealIndex: index + 2
            onClicked: Pipewire.preferredDefaultAudioSink = modelData

            Icon {
                name: "check"
                size: 20
                color: Theme.on_primary_container
                scale: item.selected ? 1 : 0

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.animNormal
                        easing.type: Easing.OutBack
                    }
                }
            }
        }
    }
}
