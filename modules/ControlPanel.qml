import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire
import QtQuick
import ".."
import "../components"

// The control panel, in control-panel-script's place (Super+Q): one of the
// rofi-shaped menus (LauncherWindow), with pages. The first lists the
// settings with their states; Wi-Fi, Bluetooth, VPN, Sound and Microphone
// open their page in the same menu, Handoff, Nightlight, the charge limit
// and Keep awake switch in place, Power, Screenshot, Screen record and
// Wallpaper open their own menus, which can come back here, and OCR and
// Color picker close it and pick from the screen.
//
// Keys are the menus' (j/k, gg/G, / to filter, Enter or l to pick, q to
// close), plus h, Backspace or Esc to go back a page. Opened straight at
// a page (from the bar), there's no going back: Esc closes. On the Sound and
// Microphone pages - and + (or =) change the volume and m mutes. A secured
// network asks for its password in the filter field.
Scope {
    id: root

    required property var power
    required property var capture
    required property var region
    required property var wallpaper
    required property var keepAwake
    required property var keyboard

    // "" for the first page, else a page's name
    property string page: ""
    // The page on screen, for the bar items that open it; null when closed
    readonly property var openAt: menu.open ? page : null
    // Opened straight at a page (a bar item, `ipc call controlpanel open`):
    // no first page to go back to, so Esc closes
    property bool standalone: false

    // For the bar's right-clicks
    Component.onCompleted: Panels.controlPanel = root

    function show(page) {
        standalone = (page ?? "") !== "";
        root.page = page ?? "";
        refresh();
        menu.replay(0);
        menu.show();
    }

    function hide() {
        menu.hide();
    }

    // A bar item's click: its page, or closed if that's already showing
    function toggle(page) {
        if (openAt === page)
            hide();
        else if (menu.open)
            go(page);
        else
            show(page);
    }

    // Back from a menu this one opened (Power, Screenshot…): the first
    // page, the pick on that menu's row
    function returnFrom(key) {
        show("");
        menu.replay(Math.max(0, home.findIndex(e => e.key === key)));
    }

    function go(page) {
        const from = root.page;
        root.page = page;
        menu.prompt = "";
        refresh();
        // Back on the first page, the pick is the page just left
        menu.replay(page === "" ? Math.max(0, home.findIndex(e => e.key === from)) : 0);
    }

    function refresh() {
        handoffCheck.running = true;
        nightlightCheck.running = true;
        chargeFile.reload();
        vpnList.running = true;
    }

    // State behind the first page

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNetwork: wifiDevice?.networks.values.find(n => n.connected) ?? null
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: btAdapter?.enabled ?? false
    property bool handoffOn: false
    property bool nightlightOn: false
    property int chargeLimit: 100

    function onOff(on) {
        return on ? "On" : "Off";
    }

    readonly property var home: [
        {
            key: "wifi",
            label: "Wi-Fi",
            icon: "network-wireless",
            subtitle: !Networking.wifiEnabled ? "Off" : wifiNetwork ? wifiNetwork.name : "Not connected"
        },
        {
            key: "bluetooth",
            label: "Bluetooth",
            icon: "bluetooth",
            subtitle: !btOn ? "Off" : `${Bluetooth.devices.values.filter(d => d.connected).length} connected`
        },
        {
            key: "vpn",
            label: "VPN",
            icon: "network-vpn",
            subtitle: vpns.filter(v => v.active).map(v => v.name).join(", ") || "Off"
        },
        {
            key: "sound",
            label: "Sound",
            icon: "audio-speakers",
            subtitle: Pipewire.defaultAudioSink?.description ?? ""
        },
        {
            key: "mic",
            label: "Microphone",
            icon: "audio-input-microphone",
            subtitle: Pipewire.defaultAudioSource?.description ?? ""
        },
        {
            key: "handoff",
            label: "Handoff",
            icon: "handoff",
            trailing: onOff(handoffOn)
        },
        {
            key: "nightlight",
            label: "Nightlight",
            icon: "cs-nightlight",
            trailing: onOff(nightlightOn)
        },
        {
            key: "lightmode",
            label: "Light mode",
            icon: "preferences-desktop-theme",
            trailing: onOff(Theme.light)
        },
        {
            key: "charge",
            label: "Charge limit",
            icon: "battery",
            subtitle: chargeLimit < 100 ? `Stops at ${chargeLimit}%` : "Charges to 100%",
            trailing: onOff(chargeLimit < 100)
        },
        {
            key: "keepawake",
            label: "Keep awake",
            icon: "caffeine",
            subtitle: keepAwake.on ? "No dimming, locking or sleep" : "Locks and sleeps when idle",
            trailing: onOff(keepAwake.on)
        },
        {
            key: "power",
            label: "Power",
            icon: "system-shutdown"
        },
        {
            key: "screenshot",
            label: "Screenshot",
            icon: "applets-screenshooter"
        },
        {
            key: "record",
            label: "Screen record",
            icon: "green-recorder"
        },
        {
            key: "wallpaper",
            label: "Wallpaper",
            icon: "preferences-desktop-wallpaper"
        },
        {
            key: "ocr",
            label: "OCR",
            icon: "ocrfeeder",
            subtitle: "Copy the text in a region"
        },
        {
            key: "colorpicker",
            label: "Color picker",
            icon: "gcolor3",
            subtitle: "Copy a color from the screen"
        },
        {
            key: "keyboard",
            label: "Keyboard",
            icon: "onboard",
            subtitle: "Type on the screen",
            trailing: onOff(keyboard.open)
        }
    ]

    // Wi-Fi: a switch, then the networks, the connected one first. Sorted
    // once per visit: afterwards rows keep their place and newly found
    // networks go at the end, so nothing moves under the pick.

    property var wifiOrder: []
    readonly property var networks: {
        if (!wifiDevice || !Networking.wifiEnabled)
            return [];
        const all = wifiDevice.networks.values.filter(n => n.name !== "");
        const kept = wifiOrder.map(name => all.find(n => n.name === name)).filter(n => n);
        const rank = n => n.connected ? 0 : n.known ? 1 : 2;
        const fresh = all.filter(n => !wifiOrder.includes(n.name)).sort((a, b) => rank(a) - rank(b) || b.signalStrength - a.signalStrength);
        return kept.concat(fresh);
    }
    // Deferred: setting the order while `networks` evaluates is a loop
    onNetworksChanged: Qt.callLater(() => {
        const names = networks.map(n => n.name);
        if (page === "wifi" && names.join("\n") !== wifiOrder.join("\n"))
            wifiOrder = names;
    })
    onPageChanged: {
        wifiOrder = [];
        if (wifiDevice)
            wifiDevice.scannerEnabled = menu.open && page === "wifi";
    }
    // The network a password is asked for, and the last one tried
    property var askingFor: null
    property var tried: null
    // Network name → why it didn't connect
    property var failures: ({})

    readonly property var wifiEntries: [
        {
            key: "wifi-switch",
            label: "Use Wi-Fi",
            icon: "network-wireless",
            accent: true,
            trailing: onOff(Networking.wifiEnabled)
        }
    ].concat(networks.map(n => ({
                key: `net:${n.name}`,
                label: n.name,
                icon: "network-wireless",
                subtitle: n.connected ? "Connected" : n.state === ConnectionState.Connecting ? "Connecting…" : failures[n.name] ?? (n.known ? "Saved" : n.security === WifiSecurityType.Open ? "Open" : ""),
                trailing: `${Math.round(n.signalStrength * 100)}%`,
                checked: n.connected
            })))

    function chooseNetwork(network) {
        if (!network || network.connected)
            return;
        const f = Object.assign({}, failures);
        delete f[network.name];
        failures = f;
        tried = network;
        if (network.known || network.security === WifiSecurityType.Open) {
            network.connect();
        } else {
            askingFor = network;
            menu.prompt = `Password for ${network.name}`;
        }
    }

    Connections {
        target: root.tried

        function onConnectionFailed(reason) {
            const f = Object.assign({}, root.failures);
            f[root.tried.name] = reason === ConnectionFailReason.NoSecrets ? "Wrong password" : "Couldn't connect";
            root.failures = f;
        }
    }

    // Bluetooth: a switch, then paired devices, the connected ones first

    readonly property var btDevices: Bluetooth.devices.values.filter(d => d.paired || d.connected).sort((a, b) => b.connected - a.connected)
    readonly property var btEntries: [
        {
            key: "bt-switch",
            label: "Use Bluetooth",
            icon: "bluetooth",
            accent: true,
            trailing: onOff(btOn)
        }
    ].concat(btOn ? btDevices.map(d => ({
                    key: `bt:${d.address}`,
                    label: d.name || d.deviceName,
                    icon: d.icon || "bluetooth",
                    subtitle: d.state === BluetoothDeviceState.Connecting ? "Connecting…" : d.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…" : d.connected ? "Connected" : "",
                    trailing: d.batteryAvailable ? `${Math.round(d.battery <= 1 ? d.battery * 100 : d.battery)}%` : "",
                    checked: d.connected
                })) : [])

    function toggleDevice(device) {
        if (!device || device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting)
            return;
        if (device.connected)
            device.disconnect();
        else
            device.connect();
    }

    // Sound and Microphone: the outputs or the inputs, the current one
    // checked, under a volume slider

    readonly property var ignoredNodes: ["easyeffects_sink", "easyeffects_source"]
    function nodes(sinks) {
        return Pipewire.nodes.values.filter(n => n.isSink === sinks && !n.isStream && n.audio && !ignoredNodes.includes(n.name) && !n.name.endsWith(".monitor"));
    }
    readonly property PwNode currentNode: page === "mic" ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink

    function nodeIcon(node, sinks) {
        const text = `${node.name} ${node.description}`;
        if (!sinks)
            return /bluez|headset/i.test(text) ? "audio-headset" : "audio-input-microphone";
        if (/bluez|headphone|buds/i.test(text))
            return "audio-headphones";
        if (/hdmi|displayport|monitor/i.test(text))
            return "video-display";
        if ((node.properties ?? {})["device.form-factor"] === "internal" || /laptop/i.test(text))
            return "computer-laptop";
        return "audio-speakers";
    }

    function nodeEntries(sinks) {
        const current = sinks ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource;
        return nodes(sinks).map(n => ({
                    key: `node:${n.id}`,
                    label: n.description || n.nickname || n.name,
                    icon: nodeIcon(n, sinks),
                    checked: n === current
                }));
    }

    function nudge(by) {
        const audio = currentNode?.audio;
        if (audio)
            audio.volume = Math.max(0, Math.min(1, Math.round((audio.volume + by) * 100) / 100));
    }

    // Volume and mute are only populated for tracked nodes
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    // VPN: NetworkManager's profiles, read from nmcli; picking one connects
    // or disconnects it through `busy`. A profile named "<anything> -
    // <country>" shows that country's flag.

    // [{ name, active }]
    property var vpns: []
    // Names being connected or disconnected → what's happening
    property var vpnPending: ({})

    readonly property var vpnEntries: vpns.map(v => ({
                key: `vpn:${v.name}`,
                label: v.name,
                icon: "network-vpn",
                emoji: flagOf(v.name),
                subtitle: vpnPending[v.name] ?? (v.active ? "Connected" : ""),
                checked: v.active
            }))

    // Country name (lowercase) → flag, from the emoji picker's data, plus
    // the short names people write
    property var flags: ({})
    readonly property var countryAliases: ({
            usa: "united states",
            us: "united states",
            america: "united states",
            uk: "united kingdom",
            britain: "united kingdom",
            england: "united kingdom",
            korea: "south korea",
            uae: "united arab emirates",
            "hong kong": "hong kong sar china"
        })

    function flagOf(name) {
        // Longest first, so "x - Guinea-Bissau" isn't read as "Bissau"
        const parts = name.split("-");
        for (let i = 1; i < parts.length; i++) {
            const country = parts.slice(i).join("-").trim().toLowerCase();
            const flag = flags[countryAliases[country] ?? country];
            if (flag)
                return flag;
        }
        return "";
    }

    FileView {
        path: Qt.resolvedUrl("../data/emoji.json").toString().replace("file://", "")
        blockLoading: false
        onLoaded: {
            const flags = {};
            for (const e of JSON.parse(text())) {
                if (e.n.startsWith("flag: "))
                    flags[e.n.slice(6).toLowerCase()] = e.c;
            }
            root.flags = flags;
        }
    }

    function toggleVpn(vpn) {
        if (!vpn || vpnPending[vpn.name])
            return;
        const p = Object.assign({}, vpnPending);
        p[vpn.name] = vpn.active ? "Disconnecting…" : "Connecting…";
        vpnPending = p;
        vpnToggle.createObject(root, {
            vpn: vpn
        }).running = true;
    }

    Process {
        id: vpnList

        command: ["nmcli", "-t", "-f", "NAME,TYPE,ACTIVE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const vpns = [];
                for (const line of text.split("\n")) {
                    // NAME may hold escaped colons
                    const m = line.match(/^(.*):vpn:(yes|no)$/);
                    if (m)
                        vpns.push({
                            name: m[1].replace(/\\:/g, ":"),
                            active: m[2] === "yes"
                        });
                }
                if (JSON.stringify(vpns) !== JSON.stringify(root.vpns))
                    root.vpns = vpns;
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: menu.open && root.page === "vpn"
        onTriggered: vpnList.running = true
    }

    Component {
        id: vpnToggle

        Process {
            id: toggle

            required property var vpn
            property int code: 0
            property string err: ""
            // The exit code and stderr arrive in either order
            property int pending: 2

            function done() {
                if (--pending > 0)
                    return;
                // Only failures notify: the row shows vpnPending until now
                if (code !== 0) {
                    const reason = err.split("\n").filter(l => l.trim()).pop() || `nmcli exited with ${code}`;
                    Quickshell.execDetached(["notify-send", "-i", "network-vpn", vpn.active ? "Couldn't disconnect VPN" : "Couldn't connect VPN", `${vpn.name}: ${reason}`]);
                }
                const p = Object.assign({}, root.vpnPending);
                delete p[vpn.name];
                root.vpnPending = p;
                vpnList.running = true;
                destroy();
            }

            command: ["nmcli", "connection", vpn.active ? "down" : "up", vpn.name]
            stderr: StdioCollector {
                onStreamFinished: {
                    toggle.err = text;
                    toggle.done();
                }
            }
            onExited: code => {
                toggle.code = code;
                toggle.done();
            }
        }
    }

    // The switches' states

    Process {
        id: switcher

        onExited: root.refresh()
    }

    Process {
        id: handoffCheck

        command: ["systemctl", "--user", "is-active", "--quiet", "handoffd"]
        onExited: code => root.handoffOn = code === 0
    }

    Process {
        id: nightlightCheck

        command: ["pgrep", "-x", "wlsunset"]
        onExited: code => root.nightlightOn = code === 0
    }

    FileView {
        id: chargeFile

        path: "/sys/class/power_supply/BAT0/charge_control_end_threshold"
        printErrors: false
        onLoaded: root.chargeLimit = Number(text().trim()) || 100
    }

    // The page on screen. Its rows are plain data, replaced only when they
    // change, so a scan or a level update doesn't rebuild the list.

    readonly property var entries: {
        switch (page) {
        case "wifi":
            return wifiEntries;
        case "bluetooth":
            return btEntries;
        case "vpn":
            return vpnEntries;
        case "sound":
            return nodeEntries(true);
        case "mic":
            return nodeEntries(false);
        }
        return home;
    }
    onEntriesChanged: {
        if (JSON.stringify(entries) !== JSON.stringify(menu.entries))
            menu.entries = entries;
    }

    function activate(entry) {
        const key = entry.key;
        if (page === "") {
            if (["wifi", "bluetooth", "vpn", "sound", "mic"].includes(key)) {
                go(key);
            } else if (key === "keepawake") {
                keepAwake.toggle();
            } else if (key === "keyboard") {
                // Off the control panel first, so keys go to the window
                keyboard.toggle();
                menu.hide();
            } else if (["handoff", "nightlight", "lightmode", "charge"].includes(key)) {
                // Commands of your own, on PATH: each switches its thing
                switcher.command = ({
                        handoff: ["toggle-handoff"],
                        nightlight: ["toggle-nightlight"],
                        lightmode: ["theme-mode", "toggle"],
                        charge: ["battery-limit"]
                    })[key];
                switcher.running = true;
            } else {
                // The next menu takes the bottom centre once this one has gone
                pendingAction = key;
                menu.hide();
            }
            return;
        }
        if (key === "wifi-switch")
            Networking.wifiEnabled = !Networking.wifiEnabled;
        else if (key.startsWith("net:"))
            chooseNetwork(networks.find(n => `net:${n.name}` === key));
        else if (key === "bt-switch" && btAdapter)
            btAdapter.enabled = !btOn;
        else if (key.startsWith("bt:"))
            toggleDevice(btDevices.find(d => `bt:${d.address}` === key));
        else if (key.startsWith("vpn:"))
            toggleVpn(vpns.find(v => `vpn:${v.name}` === key));
        else if (key.startsWith("node:")) {
            const node = Pipewire.nodes.values.find(n => `node:${n.id}` === key);
            if (page === "mic")
                Pipewire.preferredDefaultAudioSource = node;
            else
                Pipewire.preferredDefaultAudioSink = node;
        }
    }

    property string pendingAction: ""

    Connections {
        target: menu

        function onOpenChanged() {
            if (root.wifiDevice)
                root.wifiDevice.scannerEnabled = menu.open && root.page === "wifi";
            if (menu.open)
                return;
            root.askingFor = null;
            menu.prompt = "";
            if (root.pendingAction === "")
                return;
            const action = root.pendingAction;
            root.pendingAction = "";
            // Once the fold-away is done, the next menu takes its place
            nextMenu.action = action;
            nextMenu.restart();
        }
    }

    Timer {
        id: nextMenu

        property string action

        interval: 200
        onTriggered: {
            // With a way back here
            if (action === "power")
                root.power.show(true);
            else if (action === "screenshot")
                root.capture.showScreenshot(true);
            else if (action === "record")
                root.capture.showRecord(true);
            else if (action === "wallpaper")
                root.wallpaper.show(true);
            // Picks from the screen, once this menu is off it
            else if (action === "ocr")
                root.region.show("text");
            else if (action === "colorpicker")
                Quickshell.execDetached(["hyprpicker", "-a"]);
        }
    }

    LauncherWindow {
        id: menu

        title: ({
                wifi: "Wi-Fi",
                bluetooth: "Bluetooth",
                vpn: "VPN",
                sound: "Sound",
                mic: "Microphone"
            })[root.page] ?? "Control panel"
        placeholder: "Filter…"
        maxRows: 8
        closeOnPick: false
        entryKey: "key"
        canGoBack: root.page !== "" && !root.standalone
        onBack: root.go("")
        onActivated: entry => root.activate(entry)
        onSubmitted: text => {
            const network = root.askingFor;
            root.askingFor = null;
            menu.prompt = "";
            if (network && text !== "")
                network.connectWithPsk(text);
        }
        onPromptCancelled: {
            root.askingFor = null;
            menu.prompt = "";
        }
        extraKeys: event => {
            if (root.page !== "sound" && root.page !== "mic")
                return false;
            switch (event.key) {
            case Qt.Key_Minus:
                root.nudge(-0.05);
                return true;
            case Qt.Key_Plus:
            case Qt.Key_Equal:
                root.nudge(0.05);
                return true;
            case Qt.Key_M:
                if (root.currentNode?.audio)
                    root.currentNode.audio.muted = !root.currentNode.audio.muted;
                return true;
            }
            return false;
        }
        header: root.page === "sound" || root.page === "mic" ? volumeSlider : null
    }

    Component {
        id: volumeSlider

        Slider {
            readonly property bool muted: root.currentNode?.audio?.muted ?? false

            value: root.currentNode?.audio?.volume ?? 0
            dimmed: muted
            icon: root.page === "mic" ? (muted ? "mic_off" : "mic") : (muted ? "volume_mute" : "volume")
            onMoved: v => {
                if (root.currentNode?.audio)
                    root.currentNode.audio.volume = v;
            }
            onIconClicked: {
                if (root.currentNode?.audio)
                    root.currentNode.audio.muted = !muted;
            }
        }
    }

    // `qs -c quickbar ipc call controlpanel toggle`, e.g. from Super+Q;
    // `… open wifi` (or bluetooth, sound, mic, vpn) opens at a page
    IpcHandler {
        target: "controlpanel"

        function toggle(): void {
            menu.open ? root.hide() : root.show("");
        }

        function open(page: string): void {
            root.show(page);
        }
    }
}
