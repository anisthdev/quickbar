import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import ".."
import "../components"
import "music"

// The music library as one of the shell's menus: a panel at the bottom
// centre that springs open upwards, with tabs for Songs, Albums, Artists
// and Playlists, a field searching the one open, and what mpd is playing at
// its foot (NowPlayingBar). An album, an artist, a playlist or the queue
// opens as a page over the tab (DetailPage); pages stack, so an album
// opened from its artist goes back to them, and L opens the playing song's
// lyrics the same way (LyricsPage). Playlists are mpd's own. The library is
// mpd's, read by scripts/music-library (an album a folder, as tunes files
// them); playing goes through MpdPlayer. It reopens on the tab it was left on.
//
// Keys, vim style, the list keeping them: j/k (h/l too, in the album grid)
// move, gg/G go to the ends, Ctrl+d/u by half a page. Enter plays a song
// and the rest of its list after it, or opens an album, artist or playlist
// (o too). a adds the pick to the queue's end, N plays it next, p adds it
// to a playlist (a picker: type to find one, or a new name), s changes the
// order (songs: added, title, artist; artists: most songs, name), D twice
// deletes a playlist. Q opens the queue (as a click on the player does), S
// saves it as a playlist. Tab/Shift+Tab or 1-4 switch tabs, Space plays or
// pauses, > and < skip, / or i search, Esc clears the search and then
// closes, as q and Ctrl+w do. On a page: Enter (or l) plays from the song
// (in the queue, jumps to it), P plays it all, R shuffled, Esc, h or
// Backspace go back; in a playlist or the queue J/K move the song down and
// up and d takes it out. In the lyrics, j/k move through them and Enter (or
// l) goes to that line. ? lists the keys. In the field typing searches;
// Up/Down (Ctrl+j/k) move, Enter acts on the pick, Esc goes back to the
// list keeping the search.
Scope {
    id: root

    readonly property string script: Quickshell.shellDir + "/scripts/music-library"
    readonly property var tabs: ["Songs", "Albums", "Artists", "Playlists"]
    readonly property var songSorts: ["Added", "Title", "Artist"]
    readonly property var artistSorts: ["Most songs", "Name"]
    readonly property real rowHeight: 58
    readonly property int maxRows: 8
    readonly property int columns: 5
    // [keys, what they do], for ? (KeyHelp)
    readonly property var playerBindings: [["Space  >  <", "Play or pause, next, previous"], ["Q", "The queue (as a click on the player)"], ["L", "The song's lyrics"], ["S", "Save the queue as a playlist"]]
    readonly property var tabBindings: [["j k  ↓ ↑", "Move (h l too, across the albums)"], ["gg G  Ctrl+d/u", "The ends, half a page"], ["Enter  o  l", "Play the song and the rest after it, or open it"], ["a  N", "Add to the queue's end, play next"], ["p", "Add to a playlist"], ["s", "Change the order"], ["D D", "Delete the playlist"], ["1-4  Tab", "Switch tabs"], ["/  i", "Search (Esc back to the list)"], ...playerBindings, ["Esc  q", "Clear the search, then close"]]
    readonly property var pageBindings: [["j k  gg G", "Move"], ["Enter  l", "Play from the song (the queue: jump to it)"], ["P  R", "Play it all, shuffled"], ["a  N  p", "Queue the song, play it next, add it to a playlist"], ["J K  d", "Move the song down, up; take it out (a playlist, the queue)"], ["D D", "Delete the playlist"], ...playerBindings, ["Esc  h  Backspace", "Back"], ["q", "Close"]]
    readonly property var lyricsBindings: [["j k  gg G", "Move through them; they follow again after a moment"], ["Enter  l", "Go to the line (as a click on it)"], ...playerBindings, ["Esc  h  Backspace", "Back"], ["q", "Close"]]

    property bool open: false
    // In the search field rather than on the list
    property bool typing: false
    // The library, kept between openings, so it shows at once while it's
    // read again
    property var library: null
    property int tab: saved.tab
    property int songSort: 0
    property int artistSort: 0
    // The pages open over the tab, the last on top
    property var pages: []
    readonly property var page: pages.length > 0 ? pages[pages.length - 1] : null
    readonly property bool lyricsOpen: page?.kind === "lyrics"
    // What the right of the header says for a moment, e.g. "Queued"
    property string flash
    // The playlist a first D asked to delete
    property string pendingDelete
    // mpc commands changing playlists, run one after another
    property var edits: []

    // Every song, with its album's title, folder and cover
    readonly property var songs: {
        const out = [];
        for (const a of library?.albums ?? [])
            for (const t of a.tracks)
                out.push({
                    file: t.file,
                    title: t.title,
                    artist: t.artist,
                    album: a.title,
                    dir: a.dir,
                    cover: a.cover,
                    seconds: t.seconds,
                    added: t.added ?? a.added,
                    track: t.track
                });
        return out;
    }
    readonly property var sortedSongs: {
        const s = songs.slice();
        const text = x => (x ?? "").toLowerCase();
        if (songSort === 1)
            s.sort((a, b) => text(a.title).localeCompare(text(b.title)));
        else if (songSort === 2)
            s.sort((a, b) => text(a.artist).localeCompare(text(b.artist)) || text(a.album).localeCompare(text(b.album)) || a.track - b.track);
        else
            s.sort((a, b) => b.added - a.added || text(a.album).localeCompare(text(b.album)) || a.track - b.track);
        return s;
    }
    // Albums, newest first (as the script lists them), with their songs
    readonly property var albums: (library?.albums ?? []).map(a => Object.assign({}, a, {
                songs: songs.filter(s => s.dir === a.dir)
            }))
    // Everyone credited on a song, each with their songs and albums; "A, B
    // feat. C" credits all three
    readonly property var artists: {
        const byName = {};
        for (const s of songs)
            for (const name of splitArtists(s.artist)) {
                const key = name.toLowerCase();
                const a = byName[key] ?? (byName[key] = {
                        name: name,
                        files: [],
                        dirs: [],
                        cover: ""
                    });
                a.files.push(s.file);
                if (!a.dirs.includes(s.dir))
                    a.dirs.push(s.dir);
                if (!a.cover && s.cover)
                    a.cover = s.cover;
            }
        const list = Object.values(byName).map(a => Object.assign(a, {
                songs: a.files.length,
                albums: a.dirs.length
            }));
        if (artistSort === 1)
            list.sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()));
        else
            list.sort((a, b) => b.songs - a.songs || a.name.toLowerCase().localeCompare(b.name.toLowerCase()));
        return list;
    }
    readonly property var songsByFile: {
        const by = {};
        for (const s of songs)
            by[s.file] = s;
        return by;
    }
    readonly property var playlists: library?.playlists ?? []
    readonly property string query: field.text.trim().toLowerCase()
    readonly property var shownSongs: search(sortedSongs, s => [s.title, s.artist, s.album])
    readonly property var shownAlbums: search(albums, a => [a.title, a.artist])
    readonly property var shownArtists: search(artists, a => [a.name])
    readonly property var shownPlaylists: search(playlists, p => [p.name])
    // The page's songs: the queue's and a playlist's follow mpd
    readonly property var pageSongs: {
        if (!page)
            return [];
        if (page.kind === "queue")
            return MpdPlayer.queue.map(q => Object.assign({}, songsByFile[q.file] ?? {}, q));
        if (page.kind === "playlist")
            return (playlists.find(p => p.name === page.title)?.tracks ?? []).map(t => Object.assign({}, songsByFile[t.file] ?? {}, t));
        return page.songs;
    }
    readonly property string pageInfo: {
        if (page?.kind === "queue" || page?.kind === "playlist") {
            const n = pageSongs.length;
            const parts = [count(n, "song", "songs"), runtime(pageSongs.reduce((t, s) => t + s.seconds, 0))];
            if (page.kind === "queue" && MpdPlayer.position >= 0)
                parts.push(`playing ${MpdPlayer.position + 1}`);
            const missing = pageSongs.filter(s => s.missing).length;
            if (missing)
                parts.push(`${missing} missing`);
            return parts.join("  ·  ");
        }
        return page?.info ?? "";
    }
    // The list the keys move: a page's songs, else the tab's
    readonly property var activeList: lyricsOpen ? lyricsPage.list : page ? pageView.list : [songList, albumGrid, artistList, playlistList][tab]
    readonly property var current: {
        const i = activeList?.currentIndex ?? -1;
        if (i < 0)
            return null;
        if (page)
            return pageSongs[i] ?? null;
        return [shownSongs, shownAlbums, shownArtists, shownPlaylists][tab][i] ?? null;
    }


    function splitArtists(text) {
        return (text ?? "").split(/\s*,\s*|\s+(?:feat\.?|ft\.?|featuring)\s+/i).map(s => s.trim()).filter(s => s);
    }

    // `items` matching the search, ranked as the launcher menus do: the
    // start of its first text (a title, a name), then of another, then the
    // start of a word, then anywhere
    function search(items, texts) {
        if (query === "")
            return items;
        const rank = item => {
            const t = texts(item).map(x => (x ?? "").toLowerCase());
            if (t[0].startsWith(query))
                return 0;
            if (t.slice(1).some(x => x.startsWith(query)))
                return 1;
            const all = t.join(" ");
            if (all.split(/[\s\-_.:,()]+/).some(w => w.startsWith(query)))
                return 2;
            return all.includes(query) ? 3 : -1;
        };
        return items.map((item, i) => ({
                    item,
                    i,
                    r: rank(item)
                })).filter(m => m.r >= 0).sort((a, b) => a.r - b.r || a.i - b.i).map(m => m.item);
    }

    function show() {
        reader.running = true;
        field.text = "";
        flash = "";
        pages = [];
        pendingDelete = "";
        open = true;
        for (const l of [songList, albumGrid, artistList, playlistList])
            l.currentIndex = 0;
        stopTyping();
    }

    function hide() {
        open = false;
    }

    function toggle() {
        open ? hide() : show();
    }

    function startTyping() {
        pages = [];
        typing = true;
        field.forceActiveFocus();
    }

    function stopTyping() {
        typing = false;
        keys.forceActiveFocus();
    }

    function switchTo(index) {
        pages = [];
        tab = (index + tabs.length) % tabs.length;
        saved.tab = tab;
        if (activeList) {
            activeList.currentIndex = 0;
            activeList.positionViewAtBeginning();
        }
    }

    function say(text) {
        flash = text;
        flashTimer.restart();
    }

    // "14 h 5 min", "42 min"
    function runtime(seconds) {
        const minutes = Math.round(seconds / 60);
        return minutes >= 60 ? `${Math.floor(minutes / 60)} h ${minutes % 60} min` : `${minutes} min`;
    }

    function count(n, one, many) {
        return `${n} ${n === 1 ? one : many}`;
    }

    function openAlbum(album) {
        if (!album)
            return;
        const songs = album.songs.slice().sort((a, b) => a.track - b.track);
        pages = pages.concat([{
                kind: "album",
                title: album.title,
                subtitle: album.artist,
                info: [album.year, count(songs.length, "song", "songs"), runtime(album.seconds)].filter(x => x).join("  ·  "),
                cover: album.cover,
                songs: songs
            }]);
        Qt.callLater(() => pageView.list.currentIndex = 0);
    }

    function openArtist(artist) {
        if (!artist)
            return;
        const theirs = songs.filter(s => artist.files.includes(s.file));
        // Their albums newest first, each in track order
        const order = albums.map(a => a.dir);
        theirs.sort((a, b) => order.indexOf(a.dir) - order.indexOf(b.dir) || a.track - b.track);
        pages = pages.concat([{
                kind: "artist",
                title: artist.name,
                subtitle: "",
                info: [count(artist.songs, "song", "songs"), count(artist.albums, "album", "albums"), runtime(theirs.reduce((n, s) => n + s.seconds, 0))].join("  ·  "),
                cover: artist.cover,
                songs: theirs,
                albums: albums.filter(a => artist.dirs.includes(a.dir))
            }]);
        Qt.callLater(() => pageView.list.currentIndex = 0);
    }

    function openPlaylist(playlist) {
        if (!playlist)
            return;
        pages = pages.concat([{
                kind: "playlist",
                title: playlist.name,
                subtitle: "",
                covers: playlist.covers
            }]);
        Qt.callLater(() => pageView.list.currentIndex = 0);
    }

    // mpd's queue, at the song playing
    function openQueue() {
        if (page?.kind === "queue")
            return;
        const covers = [];
        for (const q of MpdPlayer.queue) {
            const c = songsByFile[q.file]?.cover;
            if (c && !covers.includes(c))
                covers.push(c);
            if (covers.length === 4)
                break;
        }
        pages = pages.concat([{
                kind: "queue",
                title: "Queue",
                subtitle: "",
                covers: covers,
                actions: [
                    {
                        id: "save",
                        label: "Save as playlist  S",
                        icon: "add",
                        primary: true
                    }
                ]
            }]);
        Qt.callLater(() => {
            pageView.list.currentIndex = Math.max(0, MpdPlayer.position);
            pageView.list.positionViewAtIndex(pageView.list.currentIndex, ListView.Center);
        });
    }

    // The playing song's lyrics, or back from them
    function toggleLyrics() {
        if (lyricsOpen)
            back();
        else
            pages = pages.concat([{
                    kind: "lyrics",
                    songs: []
                }]);
    }

    function back() {
        pendingDelete = "";
        pages = pages.slice(0, -1);
    }

    // A page's song at `index`: the queue jumps to it, the rest play from it
    function playPage(index) {
        if (page?.kind === "queue") {
            MpdPlayer.playAt(index);
            return;
        }
        // A playlist's missing songs can't play
        const list = pageSongs.filter((s, i) => !s.missing || i === index);
        const from = list.indexOf(pageSongs[index]);
        playList(list.filter(s => !s.missing), Math.max(0, list.slice(0, from).filter(s => !s.missing).length));
    }

    function pageAction(id) {
        if (lyricsOpen)
            return;
        if (id === "play")
            playPage(0);
        else if (id === "shuffle")
            shuffle(pageSongs.filter(s => !s.missing));
        else if (id === "save")
            saveQueue();
    }

    function run(command) {
        edits = edits.concat([command]);
        nextEdit();
    }

    function nextEdit() {
        if (editor.running || edits.length === 0)
            return;
        editor.command = edits[0];
        edits = edits.slice(1);
        editor.running = true;
    }

    // A playlist's songs changed here at once, ahead of mpd
    function changePlaylist(name, change) {
        const next = Object.assign({}, library);
        next.playlists = library.playlists.map(p => p.name === name ? Object.assign({}, p, {
                    tracks: change(p.tracks.slice())
                }) : p);
        library = next;
    }

    // J/K on a playlist's or the queue's page
    function moveSong(by) {
        const i = pageView.list.currentIndex;
        const j = i + by;
        if (j < 0 || j >= pageSongs.length)
            return;
        if (page.kind === "queue") {
            MpdPlayer.moveInQueue(i, j);
            return;
        }
        run(["mpc", "-q", "moveplaylist", page.title, String(i + 1), String(j + 1)]);
        changePlaylist(page.title, t => {
            t.splice(j, 0, t.splice(i, 1)[0]);
            return t;
        });
    }

    // d on a playlist's or the queue's page
    function removeSong() {
        const i = pageView.list.currentIndex;
        const s = pageSongs[i];
        if (!s)
            return;
        if (page.kind === "queue") {
            MpdPlayer.removeFromQueue(i);
        } else {
            run(["mpc", "-q", "delplaylist", page.title, String(i + 1)]);
            changePlaylist(page.title, t => {
                t.splice(i, 1);
                return t;
            });
        }
        say(`Took out ${s.title}`);
    }

    // D once asks, D again deletes: the playlist picked, or open
    function deletePlaylist() {
        const name = page?.kind === "playlist" ? page.title : !page && tab === 3 ? current?.name : "";
        if (!name)
            return;
        if (pendingDelete !== name) {
            pendingDelete = name;
            say(`D again deletes ${name}`);
            return;
        }
        pendingDelete = "";
        run(["mpc", "-q", "rm", name]);
        const next = Object.assign({}, library);
        next.playlists = library.playlists.filter(x => x.name !== name);
        library = next;
        if (page?.kind === "playlist")
            back();
        say(`Deleted ${name}`);
    }

    // p: the pick into a playlist, through the picker
    function addToPlaylist() {
        const files = filesOf(current);
        if (files.length === 0)
            return;
        const what = nameOf(current);
        picker.ask("add", what, playlists.map(p => p.name), name => {
            if (name.includes("/"))
                return say("A playlist's name can't have a /");
            // mpd makes the playlist if there isn't one
            run(["mpc", "-q", "addplaylist", name, ...files]);
            say(`Added ${what} to ${name}`);
        });
    }

    // S: the queue as a new playlist
    function saveQueue() {
        if (MpdPlayer.queue.length === 0)
            return say("The queue is empty");
        picker.ask("save", "", playlists.map(p => p.name), name => {
            if (name.includes("/"))
                return say("A playlist's name can't have a /");
            if (playlists.some(p => p.name === name))
                return say(`${name} is already a playlist`);
            run(["mpc", "-q", "save", name]);
            say(`Saved the queue as ${name}`);
        });
    }

    // The files of what's picked: a song, an album or an artist
    function filesOf(item) {
        if (!item)
            return [];
        if (item.file)
            return item.missing ? [] : [item.file];
        if (item.tracks)
            return item.tracks.filter(t => !t.missing).map(t => t.file);
        if (item.songs?.map)
            return item.songs.slice().sort((a, b) => a.track - b.track).map(s => s.file);
        return item.files ?? [];
    }

    function nameOf(item) {
        return item?.title ?? item?.name ?? "";
    }

    // Songs from the one at `index` of `list`, the rest after it
    function playList(list, index) {
        if (list.length === 0)
            return;
        MpdPlayer.playFiles(list.map(s => s.file), index);
        hide();
    }

    function shuffle(list) {
        const files = list.map(s => s.file);
        for (let i = files.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [files[i], files[j]] = [files[j], files[i]];
        }
        if (files.length > 0) {
            MpdPlayer.playFiles(files, 0);
            hide();
        }
    }

    // Enter: plays a song, opens an album or an artist
    function activate() {
        const i = activeList?.currentIndex ?? -1;
        if (lyricsOpen)
            lyricsPage.seekPick();
        else if (page)
            playPage(i);
        else if (tab === 0)
            playList(shownSongs, i);
        else if (tab === 1)
            openAlbum(current);
        else if (tab === 2)
            openArtist(current);
        else if (tab === 3)
            openPlaylist(current);
    }

    function enqueueCurrent() {
        const files = filesOf(current);
        if (files.length === 0)
            return;
        MpdPlayer.enqueue(files);
        say(`Queued ${nameOf(current)}`);
    }

    function playNextCurrent() {
        const files = filesOf(current);
        if (files.length === 0)
            return;
        MpdPlayer.playNext(files);
        say(`${nameOf(current)} plays next`);
    }

    function changeSort() {
        if (tab === 0) {
            songSort = (songSort + 1) % songSorts.length;
            say(`By ${songSorts[songSort].toLowerCase()}`);
        } else if (tab === 2) {
            artistSort = (artistSort + 1) % artistSorts.length;
            say(`By ${artistSorts[artistSort].toLowerCase()}`);
        } else
            return;
        activeList.currentIndex = 0;
    }

    // The library as read, with the picks kept on the same song, album and
    // artist
    function setLibrary(next) {
        const views = () => [[songList, shownSongs, s => s.file], [albumGrid, shownAlbums, a => a.dir], [artistList, shownArtists, a => a.name], [playlistList, shownPlaylists, p => p.name]];
        const keep = views().map(([list, items, key]) => {
            const item = items[list.currentIndex];
            return item ? key(item) : null;
        });
        library = next;
        views().forEach(([list, items, key], n) => {
            const i = items.findIndex(x => key(x) === keep[n]);
            list.currentIndex = i >= 0 ? i : Math.min(Math.max(0, list.currentIndex), items.length - 1);
        });
    }

    // Keys either mode takes
    function playerKey(event) {
        if (typing)
            return false;
        if (event.text === " ")
            MpdPlayer.mpc("toggle");
        else if (event.text === ">")
            MpdPlayer.mpc("next");
        else if (event.text === "<")
            MpdPlayer.mpc("prev");
        else
            return false;
        return true;
    }

    // The album grid's moves: h/l along, j/k a row
    function gridKey(event) {
        if (page || tab !== 1 || event.modifiers & Qt.ControlModifier)
            return false;
        const t = event.text;
        if (t === "h" || event.key === Qt.Key_Left)
            albumGrid.moveCurrentIndexLeft();
        else if (t === "l" || event.key === Qt.Key_Right)
            albumGrid.moveCurrentIndexRight();
        else if (t === "j" || event.key === Qt.Key_Down)
            albumGrid.moveCurrentIndexDown();
        else if (t === "k" || event.key === Qt.Key_Up)
            albumGrid.moveCurrentIndexUp();
        else
            return false;
        return true;
    }

    function listKey(event) {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const t = event.text;
        if (t === "?" || event.key === Qt.Key_F1) {
            help.show(lyricsOpen ? lyricsBindings : page ? pageBindings : tabBindings);
            return true;
        }
        if (ctrl && event.key === Qt.Key_W) {
            hide();
            return true;
        }
        if (playerKey(event) || gridKey(event))
            return true;
        // A playlist's or the queue's songs move with J/K (ListKeys would
        // take them as j/k)
        const editable = page?.kind === "playlist" || page?.kind === "queue";
        if (editable && !ctrl && (t === "J" || t === "K")) {
            moveSong(t === "J" ? 1 : -1);
            return true;
        }
        if (t !== "D")
            pendingDelete = "";
        if (activeList && listKeys.handle(event))
            return true;
        if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier)) {
            switchTo(tab - 1);
            return true;
        }
        if (event.key === Qt.Key_Tab) {
            switchTo(tab + 1);
            return true;
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            activate();
            return true;
        }
        if (page && (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace || t === "h")) {
            back();
            return true;
        }
        if (event.key === Qt.Key_Escape) {
            if (field.text !== "")
                field.text = "";
            else
                hide();
            return true;
        }
        if (ctrl)
            return false;
        switch (t) {
        case "q":
            hide();
            return true;
        case "l":
        case "o":
            activate();
            return true;
        case "a":
            enqueueCurrent();
            return true;
        case "N":
            playNextCurrent();
            return true;
        case "P":
            if (page)
                pageAction("play");
            return true;
        case "R":
            if (page)
                pageAction("shuffle");
            return true;
        case "p":
            addToPlaylist();
            return true;
        case "d":
            if (editable)
                removeSong();
            return true;
        case "D":
            deletePlaylist();
            return true;
        case "Q":
            openQueue();
            return true;
        case "L":
            toggleLyrics();
            return true;
        case "S":
            saveQueue();
            return true;
        case "s":
            changeSort();
            return true;
        case "/":
        case "i":
            startTyping();
            return true;
        case "1":
        case "2":
        case "3":
        case "4":
            switchTo(parseInt(t) - 1);
            return true;
        }
        return false;
    }

    function fieldKey(event) {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const down = event.key === Qt.Key_Down || ctrl && event.key === Qt.Key_J;
        const up = event.key === Qt.Key_Up || ctrl && event.key === Qt.Key_K;
        if ((down || up) && tab === 1)
            down ? albumGrid.moveCurrentIndexRight() : albumGrid.moveCurrentIndexLeft();
        else if (down)
            listKeys.move(1);
        else if (up)
            listKeys.move(-1);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            const opens = tab !== 0;
            activate();
            if (opens)
                stopTyping();
        } else if (event.key === Qt.Key_Escape)
            stopTyping();
        else if (ctrl && event.key === Qt.Key_W)
            hide();
        else
            return false;
        return true;
    }

    Component.onCompleted: Panels.musicMenu = root

    // The tab it was left on, kept through reloads too
    PersistentProperties {
        id: saved

        reloadableId: "musicMenu"

        property int tab: 0
    }

    Process {
        id: reader

        command: [root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.setLibrary(JSON.parse(text));
                } catch (e) {}
            }
        }
    }

    // The edits, in order; the library read again once they're through
    Process {
        id: editor

        onExited: {
            if (root.edits.length > 0)
                root.nextEdit();
            else
                reader.running = true;
        }
    }

    Timer {
        id: flashTimer

        interval: 2500
        onTriggered: root.flash = ""
    }

    PanelWindow {
        id: window

        property real reveal: 0

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        // Mapped from opening until the fold-away has finished
        visible: false
        // Blurred, without Hyprland's layer slide (see looknfeel.lua)
        WlrLayershell.namespace: "quickbar-overlay"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Connections {
            target: root

            function onOpenChanged() {
                if (root.open) {
                    closeAnim.stop();
                    window.visible = true;
                    openAnim.restart();
                } else {
                    openAnim.stop();
                    closeAnim.restart();
                }
            }
        }

        NumberAnimation {
            id: openAnim

            target: window
            property: "reveal"
            to: 1
            duration: 320
            easing.type: Easing.OutBack
            easing.overshoot: 0.8
        }

        NumberAnimation {
            id: closeAnim

            target: window
            property: "reveal"
            to: 0
            duration: 150
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasizedAccel
            onFinished: window.visible = false
        }

        // A click anywhere else closes it
        MouseArea {
            anchors.fill: parent
            onClicked: root.hide()
        }

        Rectangle {
            id: panel

            // The tabs and pages all get the same room, so switching
            // doesn't jump: eight rows
            readonly property real contentHeight: root.maxRows * root.rowHeight + (root.maxRows - 1) * 2
            // Room for it all, up to most of the screen
            readonly property real fullHeight: Math.min(window.height - 32 - 60, 26 + header.height + 14 + fieldBox.height + 12 + contentHeight + (bar.visible ? 12 + bar.height : 0) + 20)

            // Bottom centre, where the shell's menus open, growing upwards
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            width: Math.min(760, window.width - 32)
            height: Math.max(0, fullHeight * window.reveal)
            radius: Theme.cardRadius
            color: Theme.surface_container
            clip: true

            // Swallow clicks on the panel itself
            MouseArea {
                anchors.fill: parent
            }

            // Laid out at full height, so folding only uncovers it
            Item {
                x: 20
                y: 26
                width: parent.width - 40
                height: panel.fullHeight - 26 - 20

                Item {
                    id: keys

                    Keys.onPressed: event => event.accepted = root.listKey(event)
                }

                ListKeys {
                    id: listKeys

                    list: root.activeList ?? songList
                    halfPage: root.page || root.tab !== 1 ? Math.floor(root.maxRows / 2) : root.columns
                }

                // The title, the tabs, and the list's size (or a word on
                // what just happened)
                Item {
                    id: header

                    width: parent.width
                    height: 34

                    Label {
                        id: title

                        x: 2
                        text: "Music"
                        color: Theme.primary
                        // rofi's 20 pt
                        font.pixelSize: 26
                        font.weight: Theme.titleWeight
                        roundness: Theme.titleRoundness
                    }

                    Row {
                        anchors.left: title.right
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Repeater {
                            model: root.tabs

                            Rectangle {
                                id: chip

                                required property string modelData
                                required property int index
                                readonly property bool on: index === root.tab

                                width: chipLabel.implicitWidth + 28
                                height: 32
                                radius: height / 2
                                color: on ? Theme.secondary_container : chipMouse.containsMouse ? Qt.alpha(Theme.on_surface, 0.08) : "transparent"

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.animFast
                                    }
                                }

                                Label {
                                    id: chipLabel

                                    anchors.centerIn: parent
                                    text: chip.modelData
                                    color: chip.on ? Theme.on_secondary_container : Theme.on_surface_variant
                                    font.pixelSize: 13
                                    font.weight: chip.on ? Font.DemiBold : Font.Medium
                                }

                                MouseArea {
                                    id: chipMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.switchTo(chip.index)
                                }
                            }
                        }
                    }

                    Label {
                        anchors.right: parent.right
                        text: {
                            if (root.flash)
                                return root.flash;
                            if (root.tab === 0)
                                return `${root.count(root.shownSongs.length, "song", "songs")}  ·  ${root.runtime(root.shownSongs.reduce((n, s) => n + s.seconds, 0))}`;
                            if (root.tab === 1)
                                return root.count(root.shownAlbums.length, "album", "albums");
                            if (root.tab === 2)
                                return root.count(root.shownArtists.length, "artist", "artists");
                            return root.count(root.shownPlaylists.length, "playlist", "playlists");
                        }
                        color: root.flash ? Theme.primary : Theme.on_surface_variant
                        font.pixelSize: 12
                    }
                }

                // Search: the open tab, as it's typed
                Rectangle {
                    id: fieldBox

                    anchors.top: header.bottom
                    anchors.topMargin: 14
                    width: parent.width
                    height: 44
                    radius: height / 2
                    // The lyrics have its room
                    visible: !root.lyricsOpen
                    color: Theme.surface_container_high
                    border.width: root.typing ? 2 : 0
                    border.color: Theme.primary

                    Icon {
                        x: 16
                        name: "search"
                        size: 18
                        color: Theme.on_surface_variant
                    }

                    TextInput {
                        id: field

                        anchors.left: parent.left
                        anchors.leftMargin: 46
                        anchors.right: sortLabel.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.on_surface
                        selectionColor: Theme.primary
                        selectedTextColor: Theme.on_primary
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        clip: true
                        onTextChanged: {
                            for (const l of [songList, albumGrid, artistList, playlistList])
                                l.currentIndex = 0;
                        }
                        Keys.onPressed: event => event.accepted = root.fieldKey(event)
                        onActiveFocusChanged: if (activeFocus) {
                            root.typing = true;
                            root.pages = [];
                        }

                        Label {
                            anchors.verticalCenter: undefined
                            visible: field.text === ""
                            text: ["Search songs, artists and albums", "Search albums", "Search artists", "Search playlists"][root.tab] + "  ·  /     ? for keys"
                            color: Theme.on_surface_variant
                            font: field.font
                        }
                    }

                    // The order, which s changes
                    Label {
                        id: sortLabel

                        anchors.right: parent.right
                        anchors.rightMargin: 18
                        visible: root.tab === 0 || root.tab === 2
                        text: `By ${(root.tab === 0 ? root.songSorts[root.songSort] : root.artistSorts[root.artistSort]).toLowerCase()}  ·  s`
                        color: Theme.on_surface_variant
                        font.pixelSize: 12

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.changeSort()
                        }
                    }
                }

                // The tab's view, and a page sliding in over it
                Item {
                    id: content

                    anchors.top: root.lyricsOpen ? header.bottom : fieldBox.bottom
                    anchors.topMargin: 12
                    width: parent.width
                    height: panel.contentHeight + (root.lyricsOpen ? fieldBox.height + 14 : 0)
                    clip: true

                    Item {
                        id: tabView

                        width: parent.width
                        height: parent.height
                        x: root.page ? -32 : 0
                        opacity: root.page ? 0 : 1
                        visible: opacity > 0

                        Behavior on x {
                            NumberAnimation {
                                duration: Theme.animNormal
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.emphasizedDecel
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.animFast
                            }
                        }

                        SongList {
                            id: songList

                            anchors.fill: parent
                            opacity: root.tab === 0 ? 1 : 0
                            visible: opacity > 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.animFast
                                }
                            }
                            songs: root.shownSongs
                            onActivated: index => root.playList(root.shownSongs, index)
                        }

                        // Albums, five across, the pick's fill sliding
                        // between them
                        GridView {
                            id: albumGrid

                            anchors.fill: parent
                            opacity: root.tab === 1 ? 1 : 0
                            visible: opacity > 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.animFast
                                }
                            }
                            model: root.shownAlbums
                            cellWidth: width / root.columns
                            cellHeight: cellWidth + 46
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            highlightRangeMode: GridView.ApplyRange
                            preferredHighlightBegin: 0
                            preferredHighlightEnd: height
                            highlightFollowsCurrentItem: false
                            highlight: Rectangle {
                                id: cellFill

                                property bool settled: false

                                Component.onCompleted: Qt.callLater(() => settled = true)

                                x: albumGrid.currentItem?.x ?? 0
                                y: albumGrid.currentItem?.y ?? 0
                                width: albumGrid.cellWidth
                                height: albumGrid.cellHeight
                                radius: Theme.cardRadius
                                color: Theme.secondary_container

                                Behavior on x {
                                    enabled: cellFill.settled
                                    NumberAnimation {
                                        duration: 220
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                Behavior on y {
                                    enabled: cellFill.settled
                                    NumberAnimation {
                                        duration: 220
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            delegate: AlbumCell {
                                required property var modelData
                                required property int index

                                width: albumGrid.cellWidth
                                height: albumGrid.cellHeight
                                album: modelData
                                current: index === albumGrid.currentIndex
                                onClicked: albumGrid.currentIndex = index
                                onActivated: root.openAlbum(modelData)
                            }
                        }

                        // Artists, as the songs' rows
                        ListView {
                            id: artistList

                            anchors.fill: parent
                            opacity: root.tab === 2 ? 1 : 0
                            visible: opacity > 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.animFast
                                }
                            }
                            model: root.shownArtists
                            spacing: 2
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            highlightRangeMode: ListView.ApplyRange
                            preferredHighlightBegin: 0
                            preferredHighlightEnd: height
                            highlightFollowsCurrentItem: false
                            highlight: Rectangle {
                                id: artistFill

                                property bool settled: false

                                Component.onCompleted: Qt.callLater(() => settled = true)

                                y: artistList.currentItem?.y ?? 0
                                width: artistList.width
                                height: root.rowHeight
                                radius: Theme.radius
                                color: Theme.secondary_container

                                Behavior on y {
                                    enabled: artistFill.settled
                                    NumberAnimation {
                                        duration: 220
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            delegate: ArtistRow {
                                id: artistRow

                                required property var modelData
                                required property int index

                                width: artistList.width
                                height: root.rowHeight
                                artist: modelData
                                current: index === artistList.currentIndex
                                onClicked: artistList.currentIndex = index
                                onActivated: root.openArtist(modelData)

                                Rectangle {
                                    parent: artistList.contentItem
                                    z: -1
                                    x: artistRow.x
                                    y: artistRow.y
                                    width: artistRow.width
                                    height: artistRow.height
                                    topLeftRadius: artistRow.index === 0 ? Theme.radius : 3
                                    topRightRadius: artistRow.index === 0 ? Theme.radius : 3
                                    bottomLeftRadius: artistRow.index === artistList.count - 1 ? Theme.radius : 3
                                    bottomRightRadius: artistRow.index === artistList.count - 1 ? Theme.radius : 3
                                    color: artistRow.hovered && !artistRow.current ? Theme.surface_container_highest : Theme.surface_container_high
                                }
                            }
                        }

                        // Playlists, as the songs' rows
                        ListView {
                            id: playlistList

                            anchors.fill: parent
                            opacity: root.tab === 3 ? 1 : 0
                            visible: opacity > 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.animFast
                                }
                            }
                            model: root.shownPlaylists
                            spacing: 2
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            highlightRangeMode: ListView.ApplyRange
                            preferredHighlightBegin: 0
                            preferredHighlightEnd: height
                            highlightFollowsCurrentItem: false
                            highlight: Rectangle {
                                id: playlistFill

                                property bool settled: false

                                Component.onCompleted: Qt.callLater(() => settled = true)

                                y: playlistList.currentItem?.y ?? 0
                                width: playlistList.width
                                height: root.rowHeight
                                radius: Theme.radius
                                color: Theme.secondary_container

                                Behavior on y {
                                    enabled: playlistFill.settled
                                    NumberAnimation {
                                        duration: 220
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            delegate: PlaylistRow {
                                id: playlistRow

                                required property var modelData
                                required property int index

                                width: playlistList.width
                                height: root.rowHeight
                                playlist: modelData
                                current: index === playlistList.currentIndex
                                onClicked: playlistList.currentIndex = index
                                onActivated: root.openPlaylist(modelData)

                                Rectangle {
                                    parent: playlistList.contentItem
                                    z: -1
                                    x: playlistRow.x
                                    y: playlistRow.y
                                    width: playlistRow.width
                                    height: playlistRow.height
                                    topLeftRadius: playlistRow.index === 0 ? Theme.radius : 3
                                    topRightRadius: playlistRow.index === 0 ? Theme.radius : 3
                                    bottomLeftRadius: playlistRow.index === playlistList.count - 1 ? Theme.radius : 3
                                    bottomRightRadius: playlistRow.index === playlistList.count - 1 ? Theme.radius : 3
                                    color: playlistRow.hovered && !playlistRow.current ? Theme.surface_container_highest : Theme.surface_container_high
                                }
                            }
                        }

                        // Nothing to show, or not yet
                        Label {
                            anchors.centerIn: parent
                            visible: (root.activeList?.count ?? 0) === 0
                            text: !root.library ? "Reading the library…" : root.query ? "Nothing matches" : root.tab === 3 ? "No playlists yet: p adds songs to a new one" : "No music yet: Music search downloads it"
                            color: Theme.on_surface_variant
                            font.weight: Font.Normal
                        }
                    }

                    DetailPage {
                        id: pageView

                        width: parent.width
                        height: parent.height
                        x: root.page && !root.lyricsOpen ? 0 : 48
                        opacity: root.page && !root.lyricsOpen ? 1 : 0
                        visible: opacity > 0
                        page: root.page ? Object.assign({}, root.page, {
                            info: root.pageInfo
                        }) : null
                        songs: root.pageSongs
                        onPlay: index => root.playPage(index)
                        onAction: id => root.pageAction(id)
                        onOpenAlbum: album => root.openAlbum(album)
                        onBack: root.back()

                        Behavior on x {
                            NumberAnimation {
                                duration: Theme.animNormal
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.emphasizedDecel
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.animFast
                            }
                        }
                    }

                    LyricsPage {
                        id: lyricsPage

                        width: parent.width
                        height: parent.height
                        x: root.lyricsOpen ? 0 : 48
                        opacity: root.lyricsOpen ? 1 : 0
                        visible: opacity > 0
                        shown: root.open && root.lyricsOpen
                        onBack: root.back()

                        Behavior on x {
                            NumberAnimation {
                                duration: Theme.animNormal
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.emphasizedDecel
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.animFast
                            }
                        }
                    }
                }

                NowPlayingBar {
                    id: bar

                    lyricsOpen: root.lyricsOpen
                    onLyrics: root.toggleLyrics()

                    anchors.bottom: parent.bottom
                    width: parent.width
                    visible: MpdPlayer.active
                    onOpened: root.openQueue()
                }

                // p and S's playlist picker, over it all
                PlaylistPicker {
                    id: picker

                    anchors.margins: -12
                    onFinished: root.typing ? field.forceActiveFocus() : keys.forceActiveFocus()
                }

                KeyHelp {
                    id: help

                    anchors.margins: -12
                    onFinished: keys.forceActiveFocus()
                }
            }
        }
    }

    // `qs -c quickbar ipc call musicmenu toggle`, e.g. from Super+Shift+M;
    // open from the downloads dropdown's music rows
    IpcHandler {
        target: "musicmenu"

        function toggle(): void {
            root.toggle();
        }

        function open(): void {
            if (!root.open)
                root.show();
        }

        function lyrics(): void {
            if (!root.open)
                root.show();
            if (!root.lyricsOpen)
                root.toggleLyrics();
        }
    }
}
