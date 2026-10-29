import Quickshell
import Quickshell.Io
import QtQuick
import Qt.labs.folderlistmodel
import ".."
import "../components"

// The file chooser every app gets, in the GTK portal's place: requests come
// from scripts/filechooser-portal (the portal backend) over a socket, one at
// a time (docs/filechooser.md). One of the rofi-shaped menus, browsing a
// folder: folders first, pictures as their own icon.
//
// Keys are the menus', plus a file manager's: j/k, gg/G, Ctrl+d/u move;
// Enter, l or Right opens a folder or picks a file; h, Left, Backspace or -
// goes up; ~ goes home; . shows hidden files; / filters the folder; f
// cycles the app's file types; q or Esc cancels. Picking several, Space
// marks files and Enter takes the marked ones. Choosing a folder, the top
// row (or s) takes the one shown. Saving opens typing the name, its stem
// selected: Enter saves (asking first before replacing a file), Esc goes to
// the folder to move around in, and s or the top row comes back to the name.
Scope {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string socketDir: Quickshell.env("XDG_RUNTIME_DIR") + "/quickbar"
    readonly property string socketPath: socketDir + "/filechooser.sock"

    // Requests waiting, the first one shown: [{ socket, request }]
    property var queue: []
    // The one on screen, until it's answered
    property var current: null
    readonly property var request: current?.request ?? null
    readonly property bool saving: request?.mode === "save"
    readonly property bool pickFolder: request?.directory ?? false

    property string folder: home
    // Where the last pick was, for apps that don't say where to start
    property string lastFolder: home
    property bool showHidden: false
    property int filterIndex: -1
    readonly property var filter: request?.filters[filterIndex] ?? null
    // Paths marked with Space → true
    property var marked: ({})
    // The name to save as
    property string name: ""
    // Typing the name
    property bool naming: false
    // A file a save would replace, waiting for a yes
    property string replacing: ""
    // A folder to put the pick on once listed (the one just left)
    property string selectAfter: ""

    // [{ key, label, subtitle, icon, path, isDir, checked, accent, action }]
    property var entries: []

    function pretty(path) {
        return path === home ? "~" : path.startsWith(home + "/") ? "~" + path.slice(home.length) : path;
    }

    function join(dir, name) {
        return dir === "/" ? "/" + name : `${dir}/${name}`;
    }

    function parentOf(path) {
        const i = path.lastIndexOf("/");
        return i <= 0 ? "/" : path.slice(0, i);
    }

    function size(bytes) {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (bytes >= 1024 && i < units.length - 1) {
            bytes /= 1024;
            i++;
        }
        return `${i === 0 ? bytes : bytes.toFixed(bytes < 10 ? 1 : 0)} ${units[i]}`;
    }

    readonly property var places: ({
            [home]: "user-home",
            [home + "/Downloads"]: "folder-download",
            [home + "/Documents"]: "folder-documents",
            [home + "/Pictures"]: "folder-pictures",
            [home + "/Music"]: "folder-music",
            [home + "/Videos"]: "folder-videos",
            [home + "/Desktop"]: "folder-desktop"
        })
    readonly property var kinds: [[/\.(png|jpe?g|webp|gif|bmp|svg)$/i, ""], [/\.pdf$/i, "application-pdf"], [/\.(txt|md|log|conf|ini|toml|ya?ml|json)$/i, "text-x-generic"], [/\.(sh|py|js|ts|qml|c|h|cpp|rs|go|lua|rb)$/i, "text-x-script"], [/\.html?$/i, "text-html"], [/\.(zip|tar|gz|xz|bz2|zst|7z|rar)$/i, "package-x-generic"], [/\.(mp3|flac|ogg|opus|wav|m4a)$/i, "audio-x-generic"], [/\.(mp4|mkv|webm|avi|mov)$/i, "video-x-generic"], [/\.(odt|docx?|rtf)$/i, "x-office-document"], [/\.(ods|xlsx?|csv)$/i, "x-office-spreadsheet"], [/\.(odp|pptx?)$/i, "x-office-presentation"], [/\.iso$/i, "application-x-cd-image"]]

    function iconFor(path, isDir) {
        if (isDir)
            return places[path] ?? "folder";
        const kind = kinds.find(k => k[0].test(path));
        // Pictures show themselves
        return kind ? (kind[1] || path) : "text-x-generic";
    }

    function rebuild() {
        if (!request)
            return;
        const rows = [];
        if (pickFolder)
            rows.push({
                key: "@here",
                label: request.accept || "Select this folder",
                subtitle: pretty(folder),
                icon: iconFor(folder, true),
                accent: true,
                action: "here"
            });
        else if (saving)
            rows.push({
                key: "@save",
                label: `Save as ${name}`,
                subtitle: pretty(folder),
                icon: "document-save",
                accent: true,
                action: "save"
            });
        for (let i = 0; i < folderModel.count; i++) {
            const path = folderModel.get(i, "filePath");
            const isDir = folderModel.get(i, "fileIsDir");
            rows.push({
                key: path,
                label: folderModel.get(i, "fileName"),
                subtitle: isDir ? "" : `${size(folderModel.get(i, "fileSize"))} · ${Qt.formatDateTime(folderModel.get(i, "fileModified"), "d MMM yyyy")}`,
                icon: iconFor(path, isDir),
                path: path,
                isDir: isDir,
                checked: marked[path] ?? false
            });
        }
        entries = rows;
        if (selectAfter !== "") {
            const i = rows.findIndex(e => e.path === selectAfter);
            selectAfter = "";
            if (i >= 0)
                Qt.callLater(() => menu.select(i));
        }
    }

    function enter(path, from) {
        if (path === folder)
            return;
        folder = path;
        selectAfter = from ?? "";
        entries = [];
        menu.replay(0);
    }

    // A line from the portal backend
    function receive(socket, line) {
        let m;
        try {
            m = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (m.op !== "open")
            return;
        queue = queue.concat([{
                socket: socket,
                request: m
            }]);
        if (!current)
            start();
    }

    function start() {
        const job = queue[0];
        if (!job)
            return;
        const r = job.request;
        current = job;
        marked = {};
        replacing = "";
        showHidden = false;
        filterIndex = r.filter;
        name = r.name || "untitled";
        folder = r.folder || lastFolder;
        entries = [];
        menu.title = r.title || (saving ? "Save" : pickFolder ? "Select folder" : r.multiple ? "Open files" : "Open file");
        menu.show();
        if (saving)
            startNaming();
    }

    // Answers the shown request: { paths, filter } or { cancelled }
    function finish(answer) {
        const job = current;
        if (!job)
            return;
        current = null;
        if (job.socket.connected) {
            job.socket.write(JSON.stringify(answer) + "\n");
            job.socket.flush();
        }
        queue = queue.filter(j => j !== job);
        menu.prompt = "";
        naming = false;
        if (queue.length > 0)
            Qt.callLater(start);
        else
            menu.hide();
    }

    function pick(paths) {
        lastFolder = folder;
        finish({
            paths: paths,
            filter: filterIndex
        });
    }

    function startNaming() {
        naming = true;
        replacing = "";
        menu.prompt = "File name";
        const dot = name.lastIndexOf(".");
        menu.fill(name, dot > 0 ? dot : name.length);
    }

    function stopNaming() {
        naming = false;
        replacing = "";
        menu.prompt = "";
        rebuild();
    }

    function save(text) {
        const typed = text.trim();
        if (typed === "")
            return;
        name = typed;
        const path = typed.startsWith("/") ? typed : join(folder, typed);
        exists.path = path;
        exists.running = true;
    }

    // Whether a save would replace a file
    Process {
        id: exists

        property string path

        command: ["test", "-e", path]
        onExited: code => {
            if (code !== 0) {
                root.pick([path]);
                return;
            }
            root.replacing = path;
            menu.prompt = `Replace ${root.name}? Enter replaces it, Esc goes back`;
        }
    }

    function activate(entry) {
        if (!entry)
            return;
        if (entry.action === "here")
            pick([folder]);
        else if (entry.action === "save")
            startNaming();
        else if (entry.isDir)
            enter(entry.path);
        else if (saving) {
            name = entry.label;
            startNaming();
        } else if (request.multiple) {
            const paths = Object.keys(marked);
            pick(paths.length > 0 ? paths : [entry.path]);
        } else
            pick([entry.path]);
    }

    function toggleMark(entry) {
        if (!entry?.path || entry.isDir)
            return;
        const next = Object.assign({}, marked);
        if (next[entry.path])
            delete next[entry.path];
        else
            next[entry.path] = true;
        marked = next;
        rebuild();
        menu.select(entries.findIndex(e => e.key === entry.key) + 1);
    }

    FolderListModel {
        id: folderModel

        // Each part escaped, for names with # or ? in them
        folder: "file://" + root.folder.split("/").map(encodeURIComponent).join("/")
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: root.showHidden
        showFiles: !root.pickFolder
        caseSensitive: false
        sortCaseSensitive: false
        nameFilters: root.filter?.globs ?? []
        onStatusChanged: if (status === FolderListModel.Ready)
            Qt.callLater(root.rebuild)
        onCountChanged: Qt.callLater(root.rebuild)
    }

    LauncherWindow {
        id: menu

        panelWidth: 640
        maxRows: 9
        closeOnPick: false
        entryKey: "key"
        promptSecret: false
        fieldIcon: root.naming ? "edit" : "search"
        entries: root.entries
        header: pathHeader
        onActivated: entry => root.activate(entry)
        onSubmitted: text => {
            if (root.replacing !== "")
                root.pick([root.replacing]);
            else
                root.save(text);
        }
        onPromptCancelled: {
            if (root.replacing !== "")
                root.startNaming();
            else
                root.stopNaming();
        }
        // Closed by q, Esc or a click outside: cancelled
        onOpenChanged: if (!open && root.current)
            root.finish({
                cancelled: true
            })
        extraKeys: event => {
            if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier))
                return false;
            switch (event.key) {
            case Qt.Key_H:
            case Qt.Key_Left:
            case Qt.Key_Backspace:
            case Qt.Key_Minus:
                root.enter(root.parentOf(root.folder), root.folder);
                break;
            case Qt.Key_Right:
                root.activate(menu.currentEntry);
                break;
            case Qt.Key_AsciiTilde:
                root.enter(root.home);
                break;
            case Qt.Key_Period:
                root.showHidden = !root.showHidden;
                break;
            case Qt.Key_F:
                if ((root.request?.filters.length ?? 0) < 2)
                    return false;
                root.filterIndex = (root.filterIndex + 1) % root.request.filters.length;
                break;
            case Qt.Key_Space:
                if (!root.request?.multiple)
                    return false;
                root.toggleMark(menu.currentEntry);
                break;
            case Qt.Key_S:
                if (root.saving)
                    root.startNaming();
                else if (root.pickFolder)
                    root.pick([root.folder]);
                else
                    return false;
                break;
            default:
                return false;
            }
            return true;
        }
    }

    // Where it is, and the file type shown
    Component {
        id: pathHeader

        Item {
            implicitHeight: 20

            Label {
                anchors.left: parent.left
                anchors.leftMargin: 2
                width: parent.width - kind.implicitWidth - 16
                text: root.pretty(root.folder) + (root.showHidden ? "  · hidden shown" : "") + (Object.keys(root.marked).length > 0 ? `  · ${Object.keys(root.marked).length} marked` : "")
                elide: Text.ElideMiddle
                color: Theme.on_surface_variant
                font.pixelSize: 14
            }

            Label {
                id: kind

                anchors.right: parent.right
                visible: text !== ""
                text: root.filter?.name ?? ""
                color: Theme.primary
                font.pixelSize: 13
            }
        }
    }

    // The socket lives in a folder of quickbar's own
    Process {
        running: true
        command: ["mkdir", "-p", "-m", "700", root.socketDir]
        onExited: server.active = true
    }

    SocketServer {
        id: server

        path: root.socketPath
        handler: Socket {
            id: client

            parser: SplitParser {
                onRead: line => root.receive(client, line)
            }
            // The app gave up on it (or the backend went away)
            onConnectionStateChanged: if (!connected) {
                if (root.current?.socket === client)
                    root.finish({
                        cancelled: true
                    });
                else
                    root.queue = root.queue.filter(j => j.socket !== client);
            }
        }
    }
}
