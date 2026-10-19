import Quickshell.Io
import QtQuick
import "../components"

// NetworkManager state through nmcli: `nmcli monitor` says when something
// changed, and a short query reads the current connection and signal.
StatusItem {
    id: root

    property string kind: "none"
    property string name: ""
    property int strength: 0

    // Android 16 has four Wi-Fi levels, 0-3
    icon: kind === "ethernet" ? "ethernet" : kind === "wifi" ? `wifi_${Math.min(3, Math.floor(strength / 25))}` : "wifi_off"
    iconSize: kind === "wifi" ? 13 : kind === "ethernet" ? 24 : 17
    text: kind === "ethernet" ? "Ethernet" : kind === "wifi" ? name : "Disconnected"

    function parse(out) {
        const [devices, wifi] = out.split("---\n");
        let next = "none";
        let nextName = "";
        for (const line of devices.trim().split("\n")) {
            const [type, state, ...conn] = line.split(":");
            if (state !== "connected")
                continue;
            if (type === "wifi") {
                next = "wifi";
                nextName = conn.join(":");
                break;
            }
            if (type === "ethernet" && next === "none") {
                next = "ethernet";
                nextName = conn.join(":");
            }
        }
        kind = next;
        name = nextName;
        const active = (wifi ?? "").trim().split("\n").find(l => l.startsWith("*:"));
        strength = active ? parseInt(active.split(":")[1]) : 0;
    }

    Process {
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser {
            onRead: debounce.restart()
        }
    }

    Timer {
        id: debounce
        interval: 300
        onTriggered: query.running = true
    }

    // Signal strength changes don't show up in `nmcli monitor`
    Timer {
        interval: 30 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: query.running = true
    }

    Process {
        id: query
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE,CONNECTION device; echo ---; nmcli -t -f IN-USE,SIGNAL device wifi list --rescan no"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }
}
