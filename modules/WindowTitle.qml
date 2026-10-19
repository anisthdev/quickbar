import Quickshell
import Quickshell.Widgets
import QtQuick
import ".."
import "../components"

// The focused window: app icon, app name and title. Moving focus to another
// window slides the old one up and out and the new one in from below;
// an empty workspace folds the pill away to nothing.
Pill {
    id: root

    readonly property bool hasWindow: HyprState.activeAddress !== ""

    // The window on show. It trails Hyprland's focus by half a slide, but
    // takes title changes of the same window straight away.
    property string shownAddress
    property string shownClass
    property string shownTitle
    // Read through applications so it looks again once the entries load
    readonly property var entry: shownClass && DesktopEntries.applications.values.length ? DesktopEntries.heuristicLookup(shownClass) : null
    readonly property string appName: entry?.name ?? shownClass
    readonly property string appIcon: shownClass ? Quickshell.iconPath(entry?.icon ?? shownClass, true) : ""
    readonly property string title: clean(shownTitle, appName)

    // Drops the " — Mozilla Firefox" style suffix when it only names the
    // app, and the whole title when it is just the app name
    function clean(title, app) {
        const named = text => text.toLowerCase().includes(app.toLowerCase()) || text.toLowerCase().includes(shownClass.toLowerCase());
        if (!app || title.toLowerCase() === app.toLowerCase())
            return "";
        const match = title.match(/^(.*\S)\s+[-—–|·]\s+([^-—–|·]+)$/);
        return match && named(match[2]) ? match[1] : title;
    }

    function take() {
        shownAddress = HyprState.activeAddress;
        shownClass = HyprState.activeClass;
        shownTitle = HyprState.activeTitle;
    }

    function follow() {
        if (!hasWindow)
            return;
        if (HyprState.activeAddress === shownAddress) {
            if (!slide.running)
                take();
            return;
        }
        // Nothing on screen yet: no point sliding, the pill unfolds instead
        if (shownAddress === "" || implicitWidth === 0) {
            take();
            return;
        }
        slide.restart();
    }

    Connections {
        target: HyprState
        function onActiveAddressChanged() {
            Qt.callLater(root.follow);
        }
        function onActiveClassChanged() {
            Qt.callLater(root.follow);
        }
        function onActiveTitleChanged() {
            Qt.callLater(root.follow);
        }
    }
    Component.onCompleted: take()

    padding: 14
    implicitWidth: hasWindow ? Math.ceil(content.width + padding * 2) : 0
    visible: width > 0

    SequentialAnimation {
        id: slide

        // Catch a title that changed during the slide in
        onFinished: root.follow()

        NumberAnimation {
            target: line
            property: "y"
            to: -content.height
            duration: 110
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasizedAccel
        }
        ScriptAction {
            script: root.take()
        }
        NumberAnimation {
            target: line
            property: "y"
            from: content.height
            to: 0
            duration: 280
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasizedDecel
        }
    }

    Item {
        id: content

        width: line.implicitWidth
        height: root.height

        Row {
            id: line

            height: parent.height
            spacing: 8

            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.appIcon !== ""
                source: root.appIcon
                implicitSize: 18
            }

            Label {
                text: root.appName
                font.weight: Font.DemiBold
            }

            Label {
                visible: text !== ""
                width: Math.min(implicitWidth, 420)
                text: root.title
                color: Theme.on_surface_variant
                font.weight: Font.Normal
                elide: Text.ElideRight
            }
        }
    }
}
