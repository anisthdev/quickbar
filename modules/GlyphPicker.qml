import Quickshell
import Quickshell.Io
import QtQuick
import ".."
import "../components"

// The Nerd Font glyph picker, in rofi-nerdy's place (Super+Ctrl+N): the
// glyphs alone in a grid (see GridPicker), with the search field focused.
// The current glyph's name and codepoint show under the grid. Enter pastes
// the glyph where the user was typing (see Paste), Shift+Enter only copies
// it. Typing searches, word starts first: "home" finds md-home.
//
// The names come from Nerd Fonts' glyphnames.json (MIT), kept in data/.
Scope {
    id: root

    // [{ name, char, code }]
    property var glyphs: []

    readonly property var shown: {
        const q = picker.query.trim().toLowerCase();
        if (q === "")
            return glyphs;
        const rank = g => {
            if (g.name.startsWith(q))
                return 0;
            if (g.name.split(/[-_]/).some(w => w.startsWith(q)))
                return 1;
            if (g.name.includes(q))
                return 2;
            return g.code === q ? 0 : -1;
        };
        return glyphs.map((g, i) => ({
                    g,
                    i,
                    r: rank(g)
                })).filter(m => m.r >= 0).sort((a, b) => a.r - b.r || a.i - b.i).map(m => m.g);
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
                        code: names[name].code
                    });
            }
            root.glyphs = glyphs;
        }
    }

    GridPicker {
        id: picker

        title: "Glyphs"
        placeholder: "Search Nerd Font glyphs…"
        cellFont: "Symbols Nerd Font"
        entries: root.shown
        footerLeft: current?.name ?? (root.glyphs.length > 0 ? "Nothing matches" : "")
        footerRight: current ? `U+${current.code.toUpperCase()}` : ""
        onActivated: (entry, modifiers) => Paste.copy({
                text: entry.char
            }, !(modifiers & Qt.ShiftModifier))
    }

    // `qs -p <dir> ipc call glyphs toggle`, e.g. from Super+Ctrl+N
    IpcHandler {
        target: "glyphs"

        function toggle(): void {
            if (!picker.open)
                Paste.capture();
            picker.toggle();
        }
    }
}
