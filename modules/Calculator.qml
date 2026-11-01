import Quickshell
import Quickshell.Io
import QtQuick
import ".."
import "../components"

// Calculator (the Calculator key): one of the rofi-shaped menus, opened
// typing, worked out by libqalculate through qalc as it's typed, so units,
// currencies, percentages and equations all work. Under the field, the
// equation and its answer, large; Enter (or a click on the answer) copies
// the answer and closes, Esc just closes.
Scope {
    id: root

    property string result: ""
    // The expression the result is for
    property string resultFor: ""

    readonly property string expression: menu.typed.trim()
    // The answer to what's in the field now, not to something typed before
    readonly property bool current: result !== "" && resultFor === expression

    onExpressionChanged: {
        if (expression === "")
            result = resultFor = "";
        else
            calc.evaluate();
    }

    // qalc prints a minus sign; pasted elsewhere it should be a hyphen
    function copy() {
        if (!current)
            return;
        Paste.copy({
            text: result.replace(/−/g, "-")
        }, false);
        menu.hide();
    }

    // One qalc at a time: what's typed meanwhile waits for it to finish,
    // then only the latest is worked out
    Process {
        id: calc

        property bool again: false

        function evaluate() {
            if (running) {
                again = true;
                return;
            }
            command = ["qalc", "-t", root.expression];
            running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                root.result = text.trim();
                root.resultFor = calc.command[2];
            }
        }
        onExited: if (again) {
            again = false;
            Qt.callLater(evaluate);
        }
    }

    LauncherWindow {
        id: menu

        title: "Calculator"
        prompt: "Calculate…"
        promptSecret: false
        fieldIcon: "calculate"
        startTyping: true
        closeOnPick: false
        onSubmitted: root.copy()
        onPromptCancelled: menu.hide()

        // The equation, then the answer; the room kept while there's none,
        // so the menu doesn't jump as it comes and goes
        footer: Component {
            Column {
                leftPadding: 4
                rightPadding: 4
                bottomPadding: 2
                spacing: 2

                Label {
                    anchors.verticalCenter: undefined
                    width: parent.width - 8
                    text: root.result !== "" ? `${root.resultFor} =` : ""
                    color: Theme.on_surface_variant
                    font.pixelSize: 14
                    font.weight: Font.Normal
                    elide: Text.ElideLeft
                }

                Label {
                    anchors.verticalCenter: undefined
                    width: parent.width - 8
                    text: root.result
                    color: Theme.on_surface
                    opacity: root.current ? 1 : 0.6
                    font.pixelSize: 34
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: root.current ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.copy()
                    }
                }
            }
        }
    }

    // `qs -c quickbar ipc call calculator toggle`, e.g. from the Calculator key
    IpcHandler {
        target: "calculator"

        function toggle(): void {
            menu.toggle();
        }
    }
}
