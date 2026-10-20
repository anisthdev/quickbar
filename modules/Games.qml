import Quickshell
import Quickshell.Io
import QtQuick
import "../components"

// The NES games in RetroArch's playlist, with their box art, as
// retroarch-nes lists them; the current one shows its art large. Picking
// one starts it in RetroArch, full screen, quitting when its window closes.
Scope {
    id: root

    readonly property string retroarch: Quickshell.env("HOME") + "/.config/retroarch"
    readonly property string thumbs: `${retroarch}/thumbnails/Nintendo - Nintendo Entertainment System/Named_Boxarts`
    readonly property string quitOnClose: Quickshell.env("HOME") + "/.local/bin/menus/retroarch-quit-on-close.cfg"

    property var playlist: []
    // Box art files there are, by name
    property var boxarts: ({})

    function show() {
        launcher.show();
    }

    // RetroArch names art after the label, with some characters replaced;
    // retroarch-nes tries the label as is, then this
    function boxart(label) {
        if (boxarts[`${label}.png`])
            return `${thumbs}/${label}.png`;
        const sanitized = label.replace(/&/g, "_").replace(/:/g, " -").replace(/\?/g, "_");
        if (boxarts[`${sanitized}.png`])
            return `${thumbs}/${sanitized}.png`;
        return "retroarch";
    }

    FileView {
        path: `${root.retroarch}/playlists/Nintendo - Nintendo Entertainment System.lpl`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            // New games may bring new art
            artList.running = true;
            try {
                // Only games with a core set, as retroarch-nes requires
                root.playlist = JSON.parse(text()).items.filter(i => i.path && i.label && i.core_path && i.core_path !== "DETECT");
            } catch (e) {
                root.playlist = [];
            }
        }
    }

    Process {
        id: artList

        running: true
        command: ["ls", root.thumbs]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = {};
                for (const name of text.split("\n"))
                    if (name)
                        names[name] = true;
                // Only when it changed: a new list rebuilds every row
                if (JSON.stringify(names) !== JSON.stringify(root.boxarts))
                    root.boxarts = names;
            }
        }
    }

    LauncherWindow {
        id: launcher

        title: "NES"
        placeholder: "Search NES games…"
        maxRows: 6
        bigCurrent: true
        entries: root.playlist.map(game => ({
                    label: game.label,
                    icon: root.boxart(game.label),
                    path: game.path,
                    core: game.core_path.replace(/^~/, Quickshell.env("HOME"))
                }))
        onActivated: game => Quickshell.execDetached(["retroarch", "-f", `--appendconfig=${root.quitOnClose}`, "-L", game.core, game.path])
    }

    // `qs -p <dir> ipc call games toggle`
    IpcHandler {
        target: "games"

        function toggle(): void {
            launcher.open ? launcher.hide() : root.show();
        }
    }
}
