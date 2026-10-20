import Quickshell
import Quickshell.Networking
import QtQuick
import ".."
import "../components"

// Android 16 style Internet panel: a Wi-Fi switch, then nearby networks
// with the connected one first. Saved and open networks connect on click;
// other secured ones open a password field in their row. Scans only while
// the menu is open.
//
// Keys: j/k/gg/G move over the Wi-Fi switch and the networks (the list
// scrolls along), Enter or Space toggles or connects as a click does. In a
// password field, Enter connects and Esc closes it.
Dropdown {
    id: root

    readonly property var device: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property bool wifiOn: Networking.wifiEnabled

    // Connected first, then saved, then by signal; hidden SSIDs dropped.
    // Sorted once per opening: afterwards rows keep their place and newly
    // found networks go at the end, so nothing moves under the cursor.
    property var order: []
    readonly property var networks: {
        if (!device || !wifiOn)
            return [];
        const all = device.networks.values.filter(n => n.name !== "");
        const kept = order.map(name => all.find(n => n.name === name)).filter(n => n);
        const rank = n => n.connected ? 0 : n.known ? 1 : 2;
        const fresh = all.filter(n => !order.includes(n.name)).sort((a, b) => rank(a) - rank(b) || b.signalStrength - a.signalStrength);
        return kept.concat(fresh);
    }

    // Deferred: setting `order` while `networks` evaluates is a binding loop
    onNetworksChanged: Qt.callLater(() => {
        const names = networks.map(n => n.name);
        if (open && names.join("\n") !== order.join("\n"))
            order = names;
    })

    // The network whose password field is open
    property var askingPassword: null

    onOpenChanged: {
        if (device)
            device.scannerEnabled = open;
        if (open) {
            order = [];
            cursor.currentIndex = -1;
        } else {
            askingPassword = null;
        }
    }

    function signalIcon(network) {
        return `wifi_${Math.min(3, Math.floor((network?.signalStrength ?? 0) * 4))}`;
    }

    // A network's row clicked, or Enter on it: connect, or ask for its
    // password first
    function choose(network, index) {
        if (!network || network.connected)
            return;
        if (network.known || network.security === WifiSecurityType.Open)
            connect(network);
        else
            askingPassword = askingPassword === network ? null : network;
        if (askingPassword === network) {
            reveal.index = index;
            reveal.restart();
        }
    }

    function connect(network, password) {
        askingPassword = null;
        takeKeys();
        if (password !== undefined)
            network.connectWithPsk(password);
        else
            network.connect();
    }

    menuWidth: 340
    title: "Wi-Fi"
    keyHandler: event => {
        if (keys.handle(event)) {
            // Row 0 is the switch; the networks follow
            if (cursor.currentIndex > 0)
                list.positionViewAtIndex(cursor.currentIndex - 1, ListView.Contain);
            return true;
        }
        switch (event.key) {
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            if (cursor.currentIndex === 0)
                Networking.wifiEnabled = !wifiOn;
            else if (cursor.currentIndex > 0)
                choose(networks[cursor.currentIndex - 1], cursor.currentIndex - 1);
            return true;
        }
        return false;
    }

    RowCursor {
        id: cursor
        count: 1 + root.networks.length
    }

    ListKeys {
        id: keys
        list: cursor
    }

    SwitchRow {
        text: "Use Wi-Fi"
        checked: root.wifiOn
        shown: root.open
        highlighted: cursor.currentIndex === 0
        onToggled: Networking.wifiEnabled = !root.wifiOn
    }

    Label {
        id: heading

        anchors.verticalCenter: undefined
        leftPadding: 12
        topPadding: 12
        bottomPadding: 4
        visible: root.wifiOn
        text: root.networks.length > 0 ? "Available networks" : "Searching for networks…"
        color: Theme.on_surface_variant
        font.pixelSize: 13

        MenuReveal {
            target: heading
            shown: root.open
            index: 1
        }
    }

    // Five rows plus the top of a sixth, so it's clear the list scrolls.
    // ScriptModel updates rows in place, so networks found mid-scroll don't
    // reset the view.
    ListView {
        id: list

        readonly property real rowStep: 56 + spacing

        width: parent.width
        height: Math.min(contentHeight, 5 * rowStep + 22)
        spacing: 4
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: ScriptModel {
            values: root.networks
        }

        // Keep an opened password field in view once its row has grown
        Timer {
            id: reveal

            property int index: -1

            interval: Theme.animNormal + 20
            onTriggered: list.positionViewAtIndex(index, ListView.Contain)
        }

        delegate: ListItem {
            id: item

            required property WifiNetwork modelData
            required property int index
            // modelData goes null for a moment when a network drops out of
            // range, before its row is removed, hence the ?. below
            readonly property bool secured: (modelData?.security ?? WifiSecurityType.Open) !== WifiSecurityType.Open
            property string failure: ""

            width: list.width
            icon: root.signalIcon(modelData)
            iconSize: 15
            text: modelData?.name ?? ""
            subtitle: {
                if (!modelData)
                    return "";
                if (modelData.connected)
                    return "Connected";
                if (modelData.state === ConnectionState.Connecting)
                    return "Connecting…";
                if (failure !== "")
                    return failure;
                return modelData.known ? "Saved" : "";
            }
            first: index === 0
            last: index === root.networks.length - 1
            selected: modelData?.connected ?? false
            highlighted: cursor.currentIndex === index + 1
            clickable: !selected
            expanded: root.askingPassword === modelData
            shown: root.open
            revealIndex: index + 2

            onClicked: {
                failure = "";
                root.choose(modelData, index);
            }

            Connections {
                target: item.modelData

                function onConnectionFailed(reason) {
                    item.failure = reason === ConnectionFailReason.NoSecrets ? "Wrong password" : "Couldn't connect";
                }
            }

            Icon {
                visible: item.secured
                name: "lock"
                size: 22
                color: item.selected ? Theme.on_primary_container : Theme.on_surface_variant
            }

            extra: EntryField {
                width: item.width
                active: item.expanded
                onSubmitted: password => root.connect(item.modelData, password)
                onCancelled: {
                    root.askingPassword = null;
                    root.takeKeys();
                }
            }
        }
    }

    // Wi-Fi off
    Rectangle {
        id: offState

        width: parent.width
        height: 56
        radius: Theme.radius
        color: Theme.surface_container_high
        visible: !root.wifiOn

        Label {
            anchors.centerIn: parent
            text: "Wi-Fi is off"
            color: Theme.on_surface_variant
        }

        MenuReveal {
            target: offState
            shown: root.open
            index: 1
        }
    }
}
