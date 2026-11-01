import Quickshell
import Quickshell.Io
import QtQuick
import ".."
import "../components"

// The glyph picker, in rofi-nerdy's place (Super+Ctrl+N): the glyphs alone
// in a grid (see GridPicker), with the search field focused. The current
// glyph's name and codepoint show under the grid. Enter pastes the glyph
// where the user was typing (see Paste), Shift+Enter only copies it.
// Typing searches, word starts first: "home" finds md-home.
//
// Nerd Fonts' glyphs come first; the icon fonts in Config.glyphFonts follow,
// a tab each, read from the font by scripts/glyph-index (with their tags,
// searched after the names: "love" finds Lucide's heart). Tab and Shift+Tab
// switch fonts, keeping the search; the picker reopens on the last one.
//
// Nerd Fonts' names come from their glyphnames.json (MIT), kept in data/.
Scope {
    id: root

    // [{ name, char, code, tags }]
    property var nerdGlyphs: []
    // Config.glyphFonts' glyphs by index, or { error } for a font not found
    property var loaded: ({})

    // [{ name, font, glyphs, error }], Nerd Fonts first
    readonly property var sets: [
        {
            name: "Nerd Fonts",
            font: "Symbols Nerd Font",
            glyphs: nerdGlyphs,
            error: ""
        }
    ].concat((Config.glyphFonts ?? []).map((f, i) => ({
                name: f.name ?? f.font,
                font: f.font,
                glyphs: loaded[i]?.glyphs ?? [],
                error: loaded[i]?.error ?? ""
            })))
    property int setIndex: 0
    readonly property int currentSet: Math.min(setIndex, sets.length - 1)
    readonly property var set: sets[currentSet]

    readonly property var shown: {
        const glyphs = set.glyphs;
        const q = picker.query.trim().toLowerCase();
        if (q === "")
            return glyphs;
        const rank = g => {
            if (g.name.startsWith(q))
                return 0;
            if (g.name.split(/[-_]/).some(w => w.startsWith(q)))
                return 1;
            if (g.code === q)
                return 0;
            // A tag of the very word beats a name merely holding it: "love"
            // finds the heart before the clover
            const tags = g.tags ? g.tags.split(" ") : [];
            if (tags.includes(q))
                return 2;
            if (g.name.includes(q))
                return 3;
            return tags.some(w => w.startsWith(q)) ? 4 : -1;
        };
        return glyphs.map((g, i) => ({
                    g,
                    i,
                    r: rank(g)
                })).filter(m => m.r >= 0).sort((a, b) => a.r - b.r || a.i - b.i).map(m => m.g);
    }

    function cycle(step) {
        setIndex = (setIndex + step + sets.length) % sets.length;
    }

    // Reads the configured fonts again, e.g. on opening, should one have
    // been updated (glyph-index answers from its cache otherwise)
    function reload() {
        for (let i = 0; i < readers.count; i++)
            readers.objectAt(i).running = true;
    }

    FileView {
        path: Qt.resolvedUrl("../data/glyphnames.json").toString().replace("file://", "")
        blockLoading: false
        onLoaded: {
            const glyphs = [];
            const names = JSON.parse(text());
            for (const name in names) {
                if (name !== "METADATA")
                    glyphs.push({
                        name,
                        char: names[name].char,
                        code: names[name].code,
                        tags: ""
                    });
            }
            root.nerdGlyphs = glyphs;
        }
    }

    Instantiator {
        id: readers

        model: Config.glyphFonts ?? []
        onModelChanged: root.loaded = {}

        delegate: Process {
            id: reader

            required property var modelData
            required property int index

            function store(entry) {
                const loaded = Object.assign({}, root.loaded);
                loaded[index] = entry;
                root.loaded = loaded;
            }

            command: [Quickshell.shellDir + "/scripts/glyph-index", modelData.font ?? "", modelData.tags ?? ""]
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    if (text === "")
                        return;
                    try {
                        reader.store({
                            glyphs: JSON.parse(text).map(g => Object.assign(g, {
                                    tags: g.tags.toLowerCase()
                                }))
                        });
                    } catch (e) {
                        reader.store({
                            error: `Couldn't read ${reader.modelData.font}`
                        });
                    }
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    if (text !== "")
                        reader.store({
                            error: text.trim().replace(/^glyph-index: /, "").replace(/^no font/, "No font")
                        });
                }
            }
        }
    }

    GridPicker {
        id: picker

        title: "Glyphs"
        placeholder: `Search ${root.set.name} glyphs…`
        cellFont: root.set.font
        entries: root.shown
        cycle: root.sets.length > 1 ? root.cycle : null
        footerLeft: current?.name ?? (root.set.error || (root.set.glyphs.length > 0 ? "Nothing matches" : ""))
        footerRight: current ? `U+${current.code.toUpperCase()}` : ""
        onActivated: (entry, modifiers) => Paste.copy({
                text: entry.char
            }, !(modifiers & Qt.ShiftModifier))

        // The fonts, the current one filled; only with more than one
        headerShown: root.sets.length > 1
        header: Component {
            Row {
                spacing: 2

                Repeater {
                    model: root.sets

                    delegate: Rectangle {
                        id: tab

                        required property var modelData
                        required property int index
                        readonly property bool active: root.currentSet === index

                        width: (picker.columns * picker.cell - 2 * (root.sets.length - 1)) / root.sets.length
                        height: 40
                        topLeftRadius: index === 0 ? Theme.radius : 3
                        bottomLeftRadius: topLeftRadius
                        topRightRadius: index === root.sets.length - 1 ? Theme.radius : 3
                        bottomRightRadius: topRightRadius
                        color: active ? Theme.secondary_container : tabHover.containsMouse ? Theme.surface_container_highest : Theme.surface_container_high

                        Behavior on color {
                            ColorAnimation {
                                duration: 140
                            }
                        }

                        Label {
                            anchors.centerIn: parent
                            text: tab.modelData.name
                            color: tab.active ? Theme.on_secondary_container : Theme.on_surface_variant
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: tabHover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.setIndex = tab.index;
                                picker.select(0);
                            }
                        }
                    }
                }
            }
        }
    }

    // `qs -p <dir> ipc call glyphs toggle`, e.g. from Super+Ctrl+N
    IpcHandler {
        target: "glyphs"

        function toggle(): void {
            if (!picker.open) {
                Paste.capture();
                root.reload();
            }
            picker.toggle();
        }
    }
}
