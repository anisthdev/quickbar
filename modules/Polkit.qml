import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Polkit
import QtQuick
import ".."
import "../components"

// The polkit agent, in polkit-gnome's place: when something asks for
// authorisation (pkexec, systemctl, a mount), a dialog in the middle of
// the dimmed screen asks for the password, saying what it's for, with the asking action's
// icon and id. Enter tries the password; a wrong one says so and asks
// again. Esc, or a click outside, cancels.
//
// Only one agent can serve the session: while polkit-gnome runs, this one
// doesn't register.
Scope {
    id: root

    readonly property var flow: agent.flow
    property bool checking: false
    property string error: ""

    PolkitAgent {
        id: agent

        onAuthenticationRequestStarted: {
            root.checking = false;
            root.error = "";
            menu.show();
            menu.prompt = "Password";
        }
    }

    Connections {
        target: root.flow

        // Asked (again): the field is ready for it
        function onIsResponseRequiredChanged() {
            if (!root.flow.isResponseRequired)
                return;
            root.checking = false;
            menu.clearField();
        }

        function onAuthenticationFailed() {
            root.checking = false;
            root.error = "Wrong password";
            menu.clearField();
        }

        function onIsCompletedChanged() {
            if (root.flow.isCompleted)
                root.close();
        }
    }

    function close() {
        menu.prompt = "";
        menu.hide();
    }

    function cancel() {
        if (flow && !flow.isCompleted)
            flow.cancelAuthenticationRequest();
        close();
    }

    LauncherWindow {
        id: menu

        title: "Authentication required"
        fieldIcon: "lock"
        modal: true
        panelWidth: 640
        entries: []
        onSubmitted: text => {
            if (root.checking || !root.flow?.isResponseRequired || text === "")
                return;
            root.checking = true;
            root.error = "";
            root.flow.submit(text);
        }
        onPromptCancelled: root.cancel()
        // A click outside
        onOpenChanged: if (!open && root.flow && !root.flow.isCompleted)
            root.cancel()

        // What's asking, and how it went
        header: Component {
            Row {
                spacing: 16

                IconImage {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 44
                    source: Quickshell.iconPath(root.flow?.iconName || "security-high", "security-high")
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: menu.panelWidth - 40 - 60
                    spacing: 4

                    Label {
                        anchors.verticalCenter: undefined
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: root.flow?.message ?? ""
                        color: Theme.on_surface
                        font.pixelSize: 15
                    }

                    Label {
                        anchors.verticalCenter: undefined
                        width: parent.width
                        elide: Text.ElideMiddle
                        text: root.flow?.actionId ?? ""
                        color: Theme.on_surface_variant
                        font.pixelSize: 13
                    }

                    Label {
                        readonly property string info: root.flow?.supplementaryMessage ?? ""

                        anchors.verticalCenter: undefined
                        visible: text !== ""
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: root.checking ? "Checking…" : root.error || info
                        color: root.error !== "" && !root.checking || root.flow?.supplementaryIsError ? Theme.error : Theme.on_surface_variant
                        font.pixelSize: 14
                    }
                }
            }
        }
    }
}
