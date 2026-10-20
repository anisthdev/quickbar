import Quickshell
import Quickshell.Io
import QtQuick
import "../components"

// Quick note, in quick-note's place (Super+Shift+N): one of the rofi-shaped
// menus, opened typing. Enter saves the line to ~/Notes/inbox.md under
// today's heading (through the quick-note script, so the file keeps its
// shape and a notification confirms it) and closes; Esc closes. The last
// few notes show above the field, the newest nearest it, to look at.
Scope {
    id: root

    readonly property string inbox: Quickshell.env("HOME") + "/Notes/inbox.md"
    readonly property int shownNotes: 5

    // [{ label, trailing }]
    property var recent: []

    function toggle() {
        if (menu.open) {
            menu.hide();
        } else {
            inboxFile.reload();
            menu.show();
        }
    }

    // "## 16-10-26" headings, each followed by "- 18:04 text" lines
    function parse(text) {
        const today = Qt.formatDate(new Date(), "dd-MM-yy");
        const notes = [];
        let date = "";
        for (const line of text.split("\n")) {
            const heading = line.match(/^## (\d\d-\d\d-\d\d)\s*$/);
            if (heading) {
                date = heading[1];
                continue;
            }
            const note = line.match(/^- (\d\d:\d\d) (.+)$/);
            if (note)
                notes.push({
                    label: note[2],
                    // The day, unless it's today
                    trailing: date === today ? note[1] : `${date.slice(0, 5)}  ${note[1]}`
                });
        }
        recent = notes.slice(-shownNotes);
    }

    FileView {
        id: inboxFile

        path: root.inbox
        printErrors: false
        onLoaded: root.parse(text())
    }

    LauncherWindow {
        id: menu

        title: "Quick note"
        prompt: "Write a note…"
        promptSecret: false
        fieldIcon: "edit"
        fieldAtBottom: true
        startTyping: true
        closeOnPick: false
        maxRows: root.shownNotes
        entries: root.recent
        onSubmitted: text => {
            if (text.trim() !== "")
                Quickshell.execDetached([Quickshell.shellDir + "/scripts/quick-note", text]);
            menu.hide();
        }
        onPromptCancelled: menu.hide()
    }

    // `qs -p <dir> ipc call note toggle`, e.g. from Super+Shift+N
    IpcHandler {
        target: "note"

        function toggle(): void {
            root.toggle();
        }
    }
}
