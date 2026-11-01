import Quickshell
import Quickshell.Io
import QtQuick
import ".."
import "../components"

// The emoji picker (Super+.): the emoji in a grid (see GridPicker), as the
// glyph picker has them, the recently used first, then Unicode's groups in
// order. Under the field is the groups' row, as on Android's emoji
// keyboard: the current emoji's group is filled, and a click jumps to a
// group; it gives way to the results while searching. The current emoji's
// name and codepoints show under the grid. Enter pastes the emoji where the
// user was typing (see Paste), Shift+Enter only copies it.
//
// Typing searches names and keywords, word starts first ("happy" finds 😀).
// In the grid, [ and ] jump to the previous and next group.
//
// The names and keywords come from emojibase (MIT), kept in data/; the
// recently used are kept in ~/.cache/quickbar/emoji-recent.json.
Scope {
    id: root

    readonly property int maxRecent: 20
    readonly property var groups: [
        {
            icon: "schedule",
            name: "Recently used"
        },
        {
            icon: "emoji_emotions",
            name: "Smileys & emotion"
        },
        {
            icon: "emoji_people",
            name: "People & body"
        },
        {
            icon: "emoji_nature",
            name: "Animals & nature"
        },
        {
            icon: "emoji_food_beverage",
            name: "Food & drink"
        },
        {
            icon: "emoji_transportation",
            name: "Travel & places"
        },
        {
            icon: "emoji_events",
            name: "Activities"
        },
        {
            icon: "emoji_objects",
            name: "Objects"
        },
        {
            icon: "emoji_symbols",
            name: "Symbols"
        },
        {
            icon: "emoji_flags",
            name: "Flags"
        }
    ]
    // emojibase's group numbers to the row's; 2 (skin tones and hair) is
    // left out of the data
    readonly property var groupOf: ({
            0: 1,
            1: 2,
            3: 3,
            4: 4,
            5: 5,
            6: 6,
            7: 7,
            8: 8,
            9: 9
        })

    // [{ char, name, keywords, group, code }], in Unicode's order
    property var emoji: []
    // The recently used, newest first, as characters
    property var recent: []

    readonly property var all: {
        const byChar = {};
        for (const e of emoji)
            byChar[e.char] = e;
        return recent.filter(c => byChar[c]).map(c => Object.assign({}, byChar[c], {
                    group: 0
                })).concat(emoji);
    }
    // Where each group starts in `all`, -1 when it's empty
    readonly property var starts: groups.map((g, i) => all.findIndex(e => e.group === i))

    readonly property var shown: {
        const q = picker.query.trim().toLowerCase();
        if (q === "")
            return all;
        const rank = e => {
            const name = e.name.toLowerCase();
            if (name.startsWith(q))
                return 0;
            if (name.split(/[\s:-]+/).some(w => w.startsWith(q)))
                return 1;
            if (e.keywords.split(" ").some(w => w.startsWith(q)))
                return 2;
            return name.includes(q) ? 3 : -1;
        };
        return emoji.map((e, i) => ({
                    e,
                    i,
                    r: rank(e)
                })).filter(m => m.r >= 0).sort((a, b) => a.r - b.r || a.i - b.i).map(m => m.e);
    }

    function jump(step) {
        const group = picker.current?.group ?? 0;
        for (let g = group + step; g >= 0 && g < groups.length; g += step) {
            if (starts[g] >= 0)
                return picker.select(starts[g]);
        }
    }

    function remember(char) {
        recent = [char].concat(recent.filter(c => c !== char)).slice(0, maxRecent);
        recentFile.setText(JSON.stringify(recent));
    }

    FileView {
        path: Qt.resolvedUrl("../data/emoji.json").toString().replace("file://", "")
        blockLoading: false
        onLoaded: root.emoji = JSON.parse(text()).map(e => ({
                    char: e.c,
                    name: e.n.charAt(0).toUpperCase() + e.n.slice(1),
                    keywords: e.t,
                    group: root.groupOf[e.g],
                    code: e.h
                }))
    }

    FileView {
        id: recentFile

        path: Quickshell.env("HOME") + "/.cache/quickbar/emoji-recent.json"
        blockLoading: false
        printErrors: false
        onLoaded: {
            try {
                root.recent = JSON.parse(text());
            } catch (e) {}
        }
    }

    GridPicker {
        id: picker

        title: "Emoji"
        placeholder: "Search emoji…"
        cellFont: "Noto Color Emoji"
        cellTextSize: 26
        entries: root.shown
        footerLeft: current?.name ?? (root.emoji.length > 0 ? "Nothing matches" : "")
        footerRight: current ? current.code.split("-").filter(c => c !== "FE0F" && c !== "200D").map(c => `U+${c}`).join(" ") : ""
        extraKeys: event => {
            if (event.key === Qt.Key_BracketLeft || event.key === Qt.Key_BracketRight) {
                root.jump(event.key === Qt.Key_BracketLeft ? -1 : 1);
                return true;
            }
            return false;
        }
        onActivated: (entry, modifiers) => {
            root.remember(entry.char);
            Paste.copy({
                text: entry.char
            }, !(modifiers & Qt.ShiftModifier));
        }

        // The groups, the current emoji's filled; hidden while searching
        headerShown: query.trim() === ""
        header: Component {
            Row {
                spacing: 2

                Repeater {
                    model: root.groups

                    delegate: Rectangle {
                        id: tab

                        required property var modelData
                        required property int index
                        readonly property bool active: (picker.current?.group ?? -1) === index
                        readonly property bool empty: root.starts[index] < 0

                        width: (picker.columns * picker.cell - 2 * (root.groups.length - 1)) / root.groups.length
                        height: 40
                        topLeftRadius: index === 0 ? Theme.radius : 3
                        bottomLeftRadius: topLeftRadius
                        topRightRadius: index === root.groups.length - 1 ? Theme.radius : 3
                        bottomRightRadius: topRightRadius
                        color: active ? Theme.secondary_container : tabHover.containsMouse && !empty ? Theme.surface_container_highest : Theme.surface_container_high

                        Behavior on color {
                            ColorAnimation {
                                duration: 140
                            }
                        }

                        Icon {
                            anchors.centerIn: parent
                            name: tab.modelData.icon
                            size: 22
                            color: tab.active ? Theme.on_secondary_container : Theme.on_surface_variant
                            opacity: tab.empty ? 0.38 : 1
                        }

                        MouseArea {
                            id: tabHover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: tab.empty ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: picker.select(root.starts[tab.index])
                        }
                    }
                }
            }
        }
    }

    // `qs -c quickbar ipc call emoji toggle`, e.g. from Super+.
    IpcHandler {
        target: "emoji"

        function toggle(): void {
            if (!picker.open)
                Paste.capture();
            picker.toggle();
        }
    }
}
