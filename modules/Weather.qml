import Quickshell
import Quickshell.Io
import QtQuick
import ".."
import "../components"

// The weather half of the clock pill (see Glance): just the condition icon,
// with the temperature in its tooltip. Also the data behind the weather
// card. Everything comes from waybar-weather's --forecast mode, which shares
// its location lookup and icon mapping with waybar; only the rendering is
// new.
Pill {
    id: root

    readonly property string weatherDir: Quickshell.env("HOME") + "/.config/waybar/weather"
    readonly property string iconDir: weatherDir + "/.icons/dark"

    // The whole --forecast document, null until the first fetch lands
    property var data: null
    property double fetchedAt: 0

    function refresh() {
        if (!proc.running)
            proc.running = true;
    }

    padding: 8
    implicitHeight: Theme.barHeight - 10
    anchors.verticalCenter: parent?.verticalCenter
    radius: 8
    color: "transparent"
    visible: data !== null
    clickable: true
    onClicked: {
        // Stale after 10 minutes; the card fills in once the refresh lands
        if (Date.now() - fetchedAt > 10 * 60 * 1000)
            refresh();
        card.toggle();
    }

    Process {
        id: proc

        command: [root.weatherDir + "/waybar-weather", "--forecast"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.data = JSON.parse(text);
                    root.fetchedAt = Date.now();
                } catch (e) {
                    // Keep the last good data
                }
            }
        }
    }

    // A fetch that hangs would block every later refresh, so cut it off
    Timer {
        interval: 30 * 1000
        running: proc.running
        onTriggered: proc.signal(15)
    }

    Timer {
        interval: 10 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Image {
        anchors.verticalCenter: parent.verticalCenter
        source: root.data ? `file://${root.iconDir}/${root.data.current.icon}` : ""
        sourceSize: Qt.size(20, 20)
    }

    Tooltip {
        owner: root
        shown: root.hovered && !card.open
        text: root.data ? `${Math.round(root.data.current.temperature)}° · ${root.data.current.label}` : ""
        description: root.data?.location ?? ""
    }

    WeatherCard {
        id: card

        owner: root
        data: root.data
        iconDir: root.iconDir
        updatedAt: root.fetchedAt
    }

    // `qs -p <dir> ipc call weather toggle`, e.g. from a Hyprland keybind
    IpcHandler {
        target: "weather"

        function toggle(): void {
            card.toggle();
        }
    }
}
