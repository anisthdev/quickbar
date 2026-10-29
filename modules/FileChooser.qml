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
// goes up; ~ goes home; . shows hidden files; o sorts by the next of name,
// modified, size and type, O the other way round; ' lists the places
// (home's folders, GTK's bookmarks, drives), h or Esc going back; a makes
// a folder; / filters the folder, and a path typed there (/ or ~ first)
// lists what's in it to go to; f cycles the app's file types; q or Esc
// cancels. Picking several, Space marks files and Enter takes the marked
// ones. Choosing a folder, the top row (or s) takes the one shown. Saving
// opens typing the name, its stem selected: Enter saves (asking first
// before replacing a file), Esc goes to the folder to move around in, and
// s or the top row comes back to the name.
//
// The sort, hidden files and the last pick's folder are kept in Settings.
Scope {
    id: root

    readonly property string home: Quickshell.env("HOME")
    // Where udisks mounts drives
    readonly property string mediaDir: `/run/media/${Quickshell.env("USER")}`
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
    property int filterIndex: -1
    readonly property var filter: request?.filters[filterIndex] ?? null
    // Paths marked with Space → true
    property var marked: ({})
    // The name to save as
    property string name: ""
    // What the field asks for: "" (it filters), "name" (to save as),
    // "replace" (a yes to replacing `replacing`) or "folder" (a new one's name)
    property string asking: ""
    property string replacing: ""
    // Listing the places instead of the folder
    property bool placesShown: false
    // A path to put the pick on once listed (the folder just left)
    property string selectAfter: ""

    // A path typed into the filter, ~ as typed
    readonly property string typedPath: {
        const t = menu.typed.trim();
        return asking === "" && !placesShown && (t.startsWith("/") || t.startsWith("~")) ? t : "";
    }
    // The folder it's in, and that as typed, which its entries are matched by
    readonly property string typedDir: typedPath === "" ? "" : parentOf(expand((typedPath === "~" ? "~/" : typedPath) + "x"))
    readonly property string typedPrefix: typedPath === "~" ? "~/" : typedPath.slice(0, typedPath.lastIndexOf("/") + 1)

    // [{ key, label, subtitle, icon, path, isDir, checked, accent, action, section }]
    property var entries: []

    readonly property var sorts: ({
            name: [FolderListModel.Name, "A–Z", "Z–A"],
            modified: [FolderListModel.Time, "Newest first", "Oldest first"],
            size: [FolderListModel.Size, "Largest first", "Smallest first"],
            type: [FolderListModel.Type, "By type", "By type, reversed"]
        })
    readonly property var sort: sorts[Settings.fileChooserSort] ?? sorts.name

    function pretty(path) {
        return path === home ? "~" : path.startsWith(home + "/") ? "~" + path.slice(home.length) : path;
    }

    function expand(path) {
        return path === "~" ? home : path.startsWith("~/") ? home + path.slice(1) : path;
    }

    function join(dir, name) {
        return dir === "/" ? "/" + name : `${dir}/${name}`;
    }

    function parentOf(path) {
        const i = path.lastIndexOf("/");
        return i <= 0 ? "/" : path.slice(0, i);
    }

    function nameOf(path) {
        return path === "/" ? "/" : path.slice(path.lastIndexOf("/") + 1);
    }

    function urlOf(path) {
        // Each part escaped, for names with # or ? in them
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
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
            [home + "/Desktop"]: "folder-desktop",
            [home + "/Projects"]: "folder-projects"
        })
    readonly property var kinds: [[/\.(png|jpe?g|webp|gif|bmp|svg)$/i, ""], [/\.pdf$/i, "application-pdf"], [/\.(txt|md|log|conf|ini|toml|ya?ml|json)$/i, "text-x-generic"], [/\.(sh|py|js|ts|qml|c|h|cpp|rs|go|lua|rb)$/i, "text-x-script"], [/\.html?$/i, "text-html"], [/\.(zip|tar|gz|xz|bz2|zst|7z|rar)$/i, "package-x-generic"], [/\.(mp3|flac|ogg|opus|wav|m4a)$/i, "audio-x-generic"], [/\.(mp4|mkv|webm|avi|mov)$/i, "video-x-generic"], [/\.(odt|docx?|rtf)$/i, "x-office-document"], [/\.(ods|xlsx?|csv)$/i, "x-office-spreadsheet"], [/\.(odp|pptx?)$/i, "x-office-presentation"], [/\.iso$/i, "application-x-cd-image"]]

    function iconFor(path, isDir) {
        if (isDir)
            return places[path] ?? "folder";
        const kind = kinds.find(k => k[0].test(path));
        // Pictures show themselves
        return kind ? (kind[1] || path) : "text-x-generic";
    }

    // A folder model's rows as entries
    function rowsOf(model, extra) {
        const rows = [];
        for (let i = 0; i < model.count; i++) {
            const path = model.get(i, "filePath");
            const isDir = model.get(i, "fileIsDir");
            rows.push(Object.assign({
                key: path,
                label: model.get(i, "fileName"),
                subtitle: isDir ? "" : `${size(model.get(i, "fileSize"))} · ${Qt.formatDateTime(model.get(i, "fileModified"), "d MMM yyyy")}`,
                icon: iconFor(path, isDir),
                path: path,
                isDir: isDir,
                checked: marked[path] ?? false
            }, extra?.(path) ?? {}));
        }
        return rows;
    }

    // The places: home and its XDG folders, the file system, GTK's
    // bookmarks and mounted drives
    function placeRows() {
        const place = (path, label, section, icon) => ({
                    key: `place:${path}`,
                    label: label,
                    subtitle: pretty(path),
                    icon: icon ?? iconFor(path, true),
                    path: path,
                    isDir: true,
                    section: section
                });
        const rows = [place(home, "Home", "Places")];
        for (const path of userDirs)
            rows.push(place(path, nameOf(path), "Places"));
        rows.push(place("/", "File system", "Places", "drive-harddisk"));
        for (const b of bookmarks)
            rows.push(place(b.path, b.label, "Bookmarks"));
        for (let i = 0; i < drivesModel.count; i++) {
            const path = drivesModel.get(i, "filePath");
            // Without the media folder the model lists home instead
            if (parentOf(path) === mediaDir)
                rows.push(place(path, drivesModel.get(i, "fileName"), "Drives", "drive-removable-media"));
        }
        return rows;
    }

    function rebuild() {
        if (!request)
            return;
        let rows = [];
        if (placesShown) {
            rows = placeRows();
        } else if (typedPath !== "") {
            // Where the path goes, then what's in its folder, matched by the
            // path as typed
            rows.push({
                key: "@go",
                label: `Go to ${typedPath}`,
                keywords: typedPath,
                icon: "folder",
                accent: true,
                action: "go"
            });
            rows = rows.concat(rowsOf(pathModel, path => ({
                        key: `typed:${path}`,
                        subtitle: pretty(path),
                        keywords: typedPrefix + nameOf(path),
                        typed: true
                    })));
        } else {
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
            rows = rows.concat(rowsOf(folderModel));
        }
        entries = rows;
        if (selectAfter !== "") {
            const i = rows.findIndex(e => e.path === selectAfter);
            if (i >= 0) {
                selectAfter = "";
                Qt.callLater(() => menu.select(i));
            }
        }
    }

    function enter(path, from) {
        placesShown = false;
        menu.canGoBack = false;
        if (path === folder) {
            rebuild();
            return;
        }
        folder = path;
        selectAfter = from ?? "";
        entries = [];
        menu.replay(0);
    }

    function showPlaces() {
        placesShown = true;
        selectAfter = `${folder}`;
        menu.canGoBack = true;
        menu.replay(0);
        rebuild();
    }

    function hidePlaces() {
        placesShown = false;
        selectAfter = "";
        menu.canGoBack = false;
        menu.replay(0);
        rebuild();
    }

    function nextFilter() {
        const count = request?.filters.length ?? 0;
        if (count > 1)
            filterIndex = (filterIndex + 1) % count;
    }

    function cycleSort() {
        const names = Object.keys(sorts);
        Settings.fileChooserSort = names[(names.indexOf(Settings.fileChooserSort) + 1) % names.length];
        Settings.fileChooserReversed = false;
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
        queue = queue.concat([
            {
                socket: socket,
                request: m
            }
        ]);
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
        asking = "";
        replacing = "";
        placesShown = false;
        selectAfter = "";
        menu.canGoBack = false;
        filterIndex = r.filter;
        name = r.name || "untitled";
        folder = r.folder || Settings.fileChooserFolder || home;
        entries = [];
        menu.title = r.title || (saving ? "Save" : pickFolder ? "Select folder" : r.multiple ? "Open files" : "Open file");
        menu.show();
        // The model sends nothing when it's in the same folder as last time
        Qt.callLater(rebuild);
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
        asking = "";
        menu.prompt = "";
        if (queue.length > 0)
            Qt.callLater(start);
        else
            menu.hide();
    }

    function pick(paths) {
        Settings.fileChooserFolder = pickFolder ? paths[0] : parentOf(paths[0]);
        finish({
            paths: paths,
            filter: filterIndex
        });
    }

    function ask(what, prompt) {
        asking = what;
        menu.prompt = prompt;
    }

    function startNaming() {
        replacing = "";
        placesShown = false;
        menu.canGoBack = false;
        ask("name", "File name");
        const dot = name.lastIndexOf(".");
        menu.fill(name, dot > 0 ? dot : name.length);
    }

    function stopAsking() {
        asking = "";
        replacing = "";
        menu.prompt = "";
        rebuild();
    }

    function save(text) {
        const typed = text.trim();
        if (typed === "")
            return;
        const path = typed.startsWith("/") || typed.startsWith("~") ? expand(typed) : join(folder, typed);
        name = nameOf(path);
        exists.path = path;
        exists.running = true;
    }

    function makeFolder(text) {
        const typed = text.trim();
        if (typed === "")
            return;
        mkdir.path = typed.startsWith("/") || typed.startsWith("~") ? expand(typed) : join(folder, typed);
        mkdir.running = true;
    }

    // Goes where a typed path leads: into a folder, or a file picked (or,
    // saving, named)
    function go(path) {
        what.path = expand(path.replace(/\/+$/, "") || "/");
        what.running = true;
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
            root.ask("replace", `Replace ${root.name}? Enter replaces it, Esc goes back`);
        }
    }

    Process {
        id: mkdir

        property string path

        command: ["mkdir", "-p", path]
        onExited: code => {
            if (code !== 0) {
                root.ask("folder", `Couldn't make ${root.nameOf(path)}; another name?`);
                return;
            }
            root.stopAsking();
            if (root.parentOf(path) === root.folder)
                root.selectAfter = path;
            else
                root.enter(path);
        }
    }

    // What a typed path is: a folder, a file or nothing yet
    Process {
        id: what

        property string path

        command: ["sh", "-c", 'if [ -d "$1" ]; then echo dir; elif [ -e "$1" ]; then echo file; fi', "sh", path]
        stdout: StdioCollector {
            onStreamFinished: {
                const kind = text.trim();
                const path = what.path;
                if (kind === "dir") {
                    root.enter(path);
                } else if (root.saving) {
                    root.enter(root.parentOf(path));
                    root.name = root.nameOf(path);
                    root.startNaming();
                } else if (kind === "file" && !root.pickFolder) {
                    root.pick([path]);
                }
            }
        }
    }

    function activate(entry) {
        if (!entry)
            return;
        if (entry.action === "here")
            pick([folder]);
        else if (entry.action === "save")
            startNaming();
        else if (entry.action === "go")
            go(typedPath);
        else if (entry.typed && !entry.isDir)
            go(entry.path);
        else if (entry.isDir) {
            enter(entry.path);
            // Typing a path carries on from the folder
            if (entry.typed)
                Qt.callLater(() => {
                    menu.startFilter();
                    menu.fill(root.pretty(entry.path) + "/");
                });
        } else if (saving) {
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

    onTypedPathChanged: Qt.callLater(rebuild)

    FolderListModel {
        id: folderModel

        folder: root.urlOf(root.folder)
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: Settings.fileChooserHidden
        showFiles: !root.pickFolder
        caseSensitive: false
        sortCaseSensitive: false
        sortField: root.sort[0]
        sortReversed: Settings.fileChooserReversed
        nameFilters: root.filter?.globs ?? []
        onStatusChanged: if (status === FolderListModel.Ready)
            Qt.callLater(root.rebuild)
        onCountChanged: Qt.callLater(root.rebuild)
        onSortFieldChanged: Qt.callLater(root.rebuild)
        onSortReversedChanged: Qt.callLater(root.rebuild)
    }

    // The folder of a typed path
    FolderListModel {
        id: pathModel

        folder: root.urlOf(root.typedDir || root.folder)
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: Settings.fileChooserHidden
        showFiles: !root.pickFolder
        caseSensitive: false
        sortCaseSensitive: false
        nameFilters: root.filter?.globs ?? []
        onStatusChanged: if (status === FolderListModel.Ready && root.typedPath !== "")
            Qt.callLater(root.rebuild)
        onCountChanged: if (root.typedPath !== "")
            Qt.callLater(root.rebuild)
    }

    // Mounted drives, for the places
    FolderListModel {
        id: drivesModel

        folder: root.urlOf(root.mediaDir)
        showFiles: false
        showDotAndDotDot: false
    }

    // XDG_*_DIR="$HOME/…" lines; the ones that are just home are left out
    property var userDirs: []

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || root.home + "/.config") + "/user-dirs.dirs"
        printErrors: false
        onLoaded: {
            const dirs = [];
            for (const line of text().split("\n")) {
                const m = line.match(/^XDG_\w+_DIR="(.*)"$/);
                const path = m ? m[1].replace(/^\$HOME/, root.home).replace(/\/+$/, "") : "";
                if (path !== "" && path !== root.home && !dirs.includes(path))
                    dirs.push(path);
            }
            root.userDirs = dirs;
        }
    }

    // "file:///path Label" lines
    property var bookmarks: []

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || root.home + "/.config") + "/gtk-3.0/bookmarks"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const marks = [];
            for (const line of text().split("\n")) {
                const m = line.match(/^file:\/\/(\S+)(?: (.+))?$/);
                if (!m)
                    continue;
                const path = decodeURIComponent(m[1]);
                marks.push({
                    path: path,
                    label: m[2] ?? root.nameOf(path)
                });
            }
            root.bookmarks = marks;
        }
    }

    LauncherWindow {
        id: menu

        panelWidth: 640
        maxRows: 9
        closeOnPick: false
        entryKey: "key"
        promptSecret: false
        fieldIcon: root.asking === "name" || root.asking === "folder" ? "edit" : "search"
        placeholder: "Filter, or a path…"
        entries: root.entries
        header: pathHeader
        onActivated: entry => root.activate(entry)
        onBack: root.hidePlaces()
        onSubmitted: text => {
            switch (root.asking) {
            case "replace":
                root.pick([root.replacing]);
                break;
            case "folder":
                root.makeFolder(text);
                break;
            default:
                root.save(text);
            }
        }
        onPromptCancelled: {
            if (root.asking === "replace")
                root.startNaming();
            else
                root.stopAsking();
        }
        // Closed by q, Esc or a click outside: cancelled
        onOpenChanged: if (!open && root.current)
            root.finish({
                cancelled: true
            })
        extraKeys: event => {
            if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier))
                return false;
            // The places page has the menu's own keys, h and Esc going back
            if (root.placesShown)
                return false;
            switch (event.key) {
            case Qt.Key_H:
            case Qt.Key_Left:
            case Qt.Key_Backspace:
            case Qt.Key_Minus:
                if (root.typedPath !== "")
                    return false;
                root.enter(root.parentOf(root.folder), root.folder);
                break;
            case Qt.Key_Right:
                root.activate(menu.currentEntry);
                break;
            case Qt.Key_AsciiTilde:
                root.enter(root.home);
                break;
            case Qt.Key_Apostrophe:
                root.showPlaces();
                break;
            case Qt.Key_Period:
                Settings.fileChooserHidden = !Settings.fileChooserHidden;
                break;
            case Qt.Key_O:
                // A capital can come without Shift held (some layouts, wtype)
                if (event.modifiers & Qt.ShiftModifier || event.text === "O")
                    Settings.fileChooserReversed = !Settings.fileChooserReversed;
                else
                    root.cycleSort();
                break;
            case Qt.Key_A:
                root.ask("folder", "New folder's name");
                break;
            case Qt.Key_F:
                if ((root.request?.filters.length ?? 0) < 2)
                    return false;
                root.nextFilter();
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

    // Where it is, and how it's shown, with buttons for the keys' doings:
    // the file type, the sort, a new folder, the places
    Component {
        id: pathHeader

        Item {
            implicitHeight: 32

            Label {
                anchors.left: parent.left
                anchors.leftMargin: 2
                width: parent.width - tools.implicitWidth - 12
                text: root.placesShown ? "Places" : root.pretty(root.folder) + (Settings.fileChooserHidden ? "  · hidden shown" : "") + (Object.keys(root.marked).length > 0 ? `  · ${Object.keys(root.marked).length} marked` : "")
                elide: Text.ElideMiddle
                color: Theme.on_surface_variant
                font.pixelSize: 14
            }

            Row {
                id: tools

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                // The app's file type: a click shows the next
                Pill {
                    id: typePill

                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.placesShown && root.filter !== null
                    implicitHeight: 28
                    radius: height / 2
                    padding: 10
                    color: "transparent"
                    clickable: (root.request?.filters.length ?? 0) > 1
                    stateColor: Theme.primary
                    onClicked: root.nextFilter()

                    Label {
                        text: root.filter?.name ?? ""
                        color: Theme.primary
                        font.pixelSize: 13
                    }

                    Tooltip {
                        owner: typePill
                        shown: typePill.hovered && typePill.clickable
                        text: "Next file type  ·  f"
                    }
                }

                // The sort: a click sorts by the next, a right-click the
                // other way round
                Pill {
                    id: sortPill

                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.placesShown
                    implicitHeight: 28
                    radius: height / 2
                    padding: 10
                    color: "transparent"
                    clickable: true
                    stateColor: Theme.primary
                    onClicked: event => {
                        if (event.button === Qt.RightButton)
                            Settings.fileChooserReversed = !Settings.fileChooserReversed;
                        else
                            root.cycleSort();
                    }

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "sort"
                        size: 16
                        color: Theme.primary
                    }

                    Label {
                        text: root.sort[Settings.fileChooserReversed ? 2 : 1]
                        color: Theme.primary
                        font.pixelSize: 13
                    }

                    Tooltip {
                        owner: sortPill
                        shown: sortPill.hovered
                        text: "Sort by name, modified, size or type  ·  o"
                        description: "Right-click for the other way round  ·  O"
                    }
                }

                IconButton {
                    id: newFolder

                    visible: !root.placesShown
                    icon: "create_new_folder"
                    iconSize: 18
                    color: Theme.on_surface_variant
                    onClicked: root.ask("folder", "New folder's name")

                    HoverHandler {
                        id: newFolderHover
                    }

                    Tooltip {
                        owner: newFolder
                        shown: newFolderHover.hovered
                        text: "New folder  ·  a"
                    }
                }

                IconButton {
                    id: placesButton

                    icon: "bookmarks"
                    iconSize: 18
                    color: root.placesShown ? Theme.primary : Theme.on_surface_variant
                    onClicked: root.placesShown ? root.hidePlaces() : root.showPlaces()

                    HoverHandler {
                        id: placesHover
                    }

                    Tooltip {
                        owner: placesButton
                        shown: placesHover.hovered
                        text: root.placesShown ? "Back to the folder  ·  h" : "Places  ·  '"
                    }
                }
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
