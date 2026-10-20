//@ pragma UseQApplication
//@ pragma IconTheme Papirus-Dark

import Quickshell
import QtQuick
import "modules"

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
        }
    }

    Notifications {}
    MediaSearch {}
}
