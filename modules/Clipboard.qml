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
// clipse's history file is only read. p pins or unpins the current entry:
// pins are the shell's own, copies kept in $XDG_STATE_HOME/quickbar
// (clipboard-pins.json, and a pinned picture's file beside it), at the top
// and kept whatever clipse trims.
//
// Keys are the menus': j/k, gg/G, / to search the whole text, Enter or l
// to paste, Shift+Enter to copy, p to pin, q or Esc to close.
Scope {
    id: root

    readonly property string history: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/clipse/clipboard_history.json"
    readonly property string state: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickbar"
    readonly property string pinDir: state + "/clipboard-pins"

    // clipse's entries, newest first: [{ value, recorded, filePath }]
    property var clips: []
    // Ours, newest pin first: [{ value, recorded, file?, source? }], file
    // being the picture's copy and source clipse's file it came from
    property var pins: []
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

    function isImage(e) {
        return e.filePath && e.filePath !== "null";
    }

    // The pin standing for one of clipse's entries, if any
    function pinOf(e) {
        return pins.find(p => isImage(e) ? p.source === e.filePath : !p.file && p.value === e.value);
    }

    function row(e, pinned) {
        const when = root.ago(e.recorded ?? "");
        // Pins and clips apart in the key: pinning makes a new row, not the
        // old one updated in place, which misses the change when it moves
        const key = `${pinned ? "pin" : "clip"}:${e.recorded}`;
        const file = pinned ? e.file : (isImage(e) ? e.filePath : "");
        if (file)
            return {
                key: key,
                pinned: pinned,
                entry: e,
                label: "Image",
                subtitle: when,
                trailingIcon: pinned ? "keep" : "",
                icon: file,
                file: file,
                keywords: "image picture screenshot"
            };
        const lines = e.value.split("\n");
        return {
            key: key,
            pinned: pinned,
            entry: e,
            label: lines.find(l => l.trim() !== "")?.trim().replace(/\s+/g, " ") ?? "",
            subtitle: lines.length > 1 ? `${when} · ${lines.length} lines` : when,
            trailingIcon: pinned ? "keep" : "",
            // Text rows stay small among pictures
            big: false,
            text: e.value,
            keywords: e.value
        };
    }

    function rebuild() {
        items = pins.map(p => row(p, true)).concat(clips.filter(e => !pinOf(e)).map(e => row(e, false)));
    }

    function parse(text) {
        let history = [];
        try {
            history = JSON.parse(text).clipboardHistory ?? [];
        } catch (e) {}
        clips = history;
        rebuild();
    }

    function parsePins(text) {
        try {
            pins = JSON.parse(text) ?? [];
        } catch (e) {
            pins = [];
        }
        rebuild();
    }

    // Pins the entry, or unpins it, keeping the pick on it
    function togglePin(item) {
        if (!item)
            return;
        const e = item.entry;
        let key;
        if (item.pinned) {
            pins = pins.filter(p => p !== e);
            if (e.file)
                Quickshell.execDetached(["rm", "-f", e.file]);
            const back = clips.find(c => e.file ? c.filePath === e.source : !isImage(c) && c.value === e.value);
            key = back ? `clip:${back.recorded}` : "";
        } else {
            const pin = {
                value: e.value,
                recorded: e.recorded
            };
            if (isImage(e)) {
                // clipse deletes its pictures as it trims; the pin keeps a copy
                pin.source = e.filePath;
                pin.file = `${pinDir}/${e.filePath.split("/").pop()}`;
                Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && cp -f "$2" "$3"', "sh", pinDir, e.filePath, pin.file]);
            }
            pins = [pin].concat(pins);
            key = `pin:${e.recorded}`;
        }
        pinsFile.setText(JSON.stringify(pins, null, 1));
        rebuild();
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

    FileView {
        id: pinsFile

        path: root.state + "/clipboard-pins.json"
        printErrors: false
        onLoaded: root.parsePins(text())
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

    // `qs -c quickbar ipc call clipboard toggle`, e.g. from Super+V
    IpcHandler {
        target: "clipboard"

        function toggle(): void {
            root.toggle();
        }
    }
}
