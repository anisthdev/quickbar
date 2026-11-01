import Quickshell
import Quickshell.Io
import QtQuick
import "../components"

// The keybindings sheet, in keybindings' place (Super+Ctrl+K): Hyprland's
// binds with a description, as one of the rofi-shaped menus, each row the
// description with its keys as keycaps. Read from `hyprctl binds` when it
// opens, so it follows the config. Binds without a description (mouse,
// media keys, secret ones) are left out; a run of numbered binds (Focus
// workspace 1…9) is one row; a submap's binds say which.
//
// It opens in the filter (the keys match too, e.g. "alt"); Ctrl+j/k or
// the arrows move while typing, Esc goes to the list (j/k, gg/G), and q or
// Esc there closes.
Scope {
    id: root

    property var binds: []

    function toggle() {
        if (menu.open) {
            menu.hide();
        } else {
            list.running = true;
            menu.show();
        }
    }

    function mods(mask) {
        const names = [];
        if (mask & 64)
            names.push("Super");
        if (mask & 4)
            names.push("Ctrl");
        if (mask & 8)
            names.push("Alt");
        if (mask & 1)
            names.push("Shift");
        return names;
    }

    function keyName(key) {
        const names = {
            space: "Space",
            escape: "Esc",
            return: "Enter",
            print: "PrtSc",
            comma: ",",
            period: ".",
            grave: "`",
            minus: "-",
            equal: "=",
            left: "←",
            right: "→",
            up: "↑",
            down: "↓"
        };
        return names[key.toLowerCase()] ?? (key.length === 1 ? key.toUpperCase() : key);
    }

    function build(binds) {
        const rows = [];
        for (const b of binds) {
            if (!b.description || b.mouse || /^(XF86|mouse)/.test(b.key))
                continue;
            const keys = mods(b.modmask).concat([keyName(b.key)]);
            // "Focus workspace 1", "… 2": one row, the digits a range
            const numbered = b.description.match(/^(.*) (\d+)$/);
            const same = numbered && /^\d+$/.test(b.key) ? rows.find(r => r.base === numbered[1] && r.mask === b.modmask && r.submap === b.submap) : null;
            if (same) {
                same.label = `${numbered[1]} ${same.from}–${b.key}`;
                same.keys = keys.slice(0, -1).concat([`${same.from}–${b.key}`]);
                same.keywords = same.keys.join(" ");
                continue;
            }
            rows.push({
                label: b.description,
                subtitle: b.submap ? `In ${b.submap} mode` : "",
                keys,
                keywords: keys.join(" "),
                base: numbered && /^\d+$/.test(b.key) ? numbered[1] : null,
                from: b.key,
                mask: b.modmask,
                submap: b.submap
            });
        }
        root.binds = rows;
    }

    Process {
        id: list

        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.build(JSON.parse(text));
                } catch (e) {
                    root.binds = [];
                }
            }
        }
    }

    LauncherWindow {
        id: menu

        title: "Keybindings"
        placeholder: "Search keybindings…"
        // Searching is what it's for
        startTyping: true
        panelWidth: 560
        maxRows: 9
        closeOnPick: false
        entries: root.binds
    }

    // `qs -c quickbar ipc call keybindings toggle`, e.g. from Super+Ctrl+K
    IpcHandler {
        target: "keybindings"

        function toggle(): void {
            root.toggle();
        }
    }
}
