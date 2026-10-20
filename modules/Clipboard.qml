import Quickshell
import Quickshell.Io
import QtQuick
import ".."
import "../components"

// The clipboard history, in clipse-gui's place (Super+V): what `clipse
// -listen` has kept, newest first, as one of the rofi-shaped menus. Text
// shows its first line, images their picture (the current one large);
// pinned entries have a pin. Enter (or a click) copies the entry back to the
// clipboard, closes, and pastes it into the window that was focused, with
// the paste key for its kind (Ctrl+Shift+V in a terminal, Ctrl+V
// elsewhere); Shift+Enter only copies.
//
// p pins or unpins the current entry: pinned ones stay at the top, and
// clipse keeps them when it trims the history. Pins are clipse's own,
// written to its history file (clipse reads the file afresh on every
// copy, so they stick).
//
// Keys are the menus': j/k, gg/G, / to search the whole text, Enter or l
// to paste, Shift+Enter to copy, p to pin, q or Esc to close.
Scope {
    id: root

    readonly property string history: Quickshell.env("HOME") + "/.config/clipse/clipboard_history.json"

    // [{ label, subtitle, icon?, text?, file?, … }]
    property var items: []

    function toggle() {
        if (menu.open) {
            menu.hide();
        } else {
            // Picks paste where the user was typing (see Paste)
            Paste.capture();
            historyFile.reload();
            menu.show();
        }
    }

    function ago(recorded) {
        // "2026-10-20 19:08:36.783044407"
        const then = new Date(recorded.slice(0, 23).replace(" ", "T"));
        const s = Math.max(0, (Date.now() - then) / 1000);
        if (s < 60)
            return "Just now";
        if (s < 3600)
            return `${Math.floor(s / 60)} min ago`;
        if (s < 86400)
            return `${Math.floor(s / 3600)} h ago`;
        const days = Math.floor(s / 86400);
        return days === 1 ? "Yesterday" : `${days} days ago`;
    }

    function parse(text) {
        let history = [];
        try {
            history = JSON.parse(text).clipboardHistory ?? [];
        } catch (e) {}
        // Pinned first, otherwise newest first, as clipse keeps them
        history = history.filter(e => e.pinned).concat(history.filter(e => !e.pinned));
        items = history.map(e => {
            const image = e.filePath && e.filePath !== "null";
            const pinned = e.pinned === true;
            const when = root.ago(e.recorded ?? "");
            if (image)
                return {
                    // The pin in the key: a pinned entry is a new row,
                    // not the old one updated in place, which misses the
                    // change when the row moves
                    key: `${e.recorded}:${pinned}`,
                    label: "Image",
                    subtitle: when,
                    trailingIcon: pinned ? "keep" : "",
                    icon: e.filePath,
                    file: e.filePath,
                    keywords: "image picture screenshot"
                };
            const lines = e.value.split("\n");
            return {
                key: `${e.recorded}:${pinned}`,
                label: lines.find(l => l.trim() !== "")?.trim().replace(/\s+/g, " ") ?? "",
                subtitle: lines.length > 1 ? `${when} · ${lines.length} lines` : when,
                trailingIcon: pinned ? "keep" : "",
                // Text rows stay small among pictures
                big: false,
                text: e.value,
                keywords: e.value
            };
        });
    }

    // Flips an entry's pin in clipse's file, keeping the pick on it
    function togglePin(item) {
        if (!item)
            return;
        let data;
        try {
            data = JSON.parse(historyFile.text());
        } catch (e) {
            return;
        }
        const recorded = item.key.replace(/:(true|false)$/, "");
        const entry = (data.clipboardHistory ?? []).find(e => e.recorded === recorded);
        if (!entry)
            return;
        entry.pinned = !entry.pinned;
        const text = JSON.stringify(data);
        historyFile.setText(text);
        parse(text);
        const key = `${recorded}:${entry.pinned}`;
        Qt.callLater(() => menu.select(root.items.findIndex(i => i.key === key)));
    }

    FileView {
        id: historyFile

        path: root.history
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parse(text())
    }

    LauncherWindow {
        id: menu

        title: "Clipboard"
        placeholder: "Search the clipboard…"
        panelWidth: 440
        maxRows: 5
        bigCurrent: true
        entries: root.items
        entryKey: "key"
        extraKeys: event => {
            if (event.key !== Qt.Key_P || event.modifiers & Qt.ControlModifier)
                return false;
            root.togglePin(menu.currentEntry);
            return true;
        }
        onActivated: item => Paste.copy(item, !(menu.pickModifiers & Qt.ShiftModifier))
    }

    // `qs -p <dir> ipc call clipboard toggle`, e.g. from Super+V
    IpcHandler {
        target: "clipboard"

        function toggle(): void {
            root.toggle();
        }
    }
}
