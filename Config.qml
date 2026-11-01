pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Choices made by hand in ~/.config/quickbar/config.json, which the bar only
// reads; edits apply as soon as the file is saved. Unlike Settings, nothing
// here is written back.
Singleton {
    id: root

    // Phone apps whose icon is illegible at chip size, as package → icon
    // shown on their Live Update chip instead: a name from icons/ or the
    // path to an image (e.g. a Papirus symbolic icon), tinted either way
    property alias liveIcons: adapter.liveIcons
    // Scratchpads (special workspaces) as name → icon shown for them in the
    // workspaces while one is open, in the same form as liveIcons; others
    // get a generic one
    property alias scratchIcons: adapter.scratchIcons
    // Icon fonts the glyph picker searches besides Nerd Fonts, a tab each
    // (Tab switches): [{ "name": tab title, "font": fontconfig family,
    // "tags": optional JSON of glyph name → search words, e.g. Lucide's
    // tags.json }]. The glyphs are the font's own, read by
    // scripts/glyph-index
    property alias glyphFonts: adapter.glyphFonts
    // What a click on the phone's Live Update chip runs, a shell command
    // that shows the phone's screen (scrcpy, a scratchpad); without it the
    // chip isn't clickable
    property alias phoneMirror: adapter.phoneMirror

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/quickbar/config.json"
        watchChanges: true
        onFileChanged: reload()
        printErrors: false

        JsonAdapter {
            id: adapter

            property var liveIcons: ({})
            property var scratchIcons: ({})
            property var glyphFonts: []
            property string phoneMirror: ""
        }
    }
}
