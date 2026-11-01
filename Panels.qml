pragma Singleton

import Quickshell
import QtQuick

// Windows that bar items open but don't own, set by the windows themselves
Singleton {
    // The control panel: show(page) opens it at a page
    property var controlPanel: null
    // The music menu (modules/MusicMenu.qml): toggle() opens or closes it
    property var musicMenu: null
}
