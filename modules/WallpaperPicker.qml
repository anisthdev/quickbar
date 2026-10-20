import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import ".."
import "../components"

// The wallpaper picker, in wallpaper-picker's place (Super+Ctrl+Space): the
// wallpapers in ~/Wallpapers as one strip across the middle of the screen,
// from side to side, the pictures edge to edge with no gaps, looping round. The pick stays in the middle,
// grown a little over its neighbours with round corners and a shadow,
// while the others dim; moving glides the strip along. Picking one runs
// matugen on it, which sets the wallpaper (awww) and recolours everything.
// It opens on the wallpaper showing now.
//
// Keys: h/l (or j/k, the arrows, Tab) move, gg/G go to the first and last,
// Enter or Space picks, q or Esc closes. Opened from the control panel
// (show(true)), a back arrow shows by the title, and it, Backspace or Esc
// go back there. The mouse wheel moves; a click picks.
//
// Thumbnails (16:9, 480x270) are kept in ~/.cache/quickbar/wallpapers.
Scope {
    id: root

    readonly property string folder: Quickshell.env("HOME") + "/Wallpapers"
    readonly property real tileWidth: 384
    readonly property real tileHeight: 216
    readonly property real grownScale: 1.15

    property bool open: false
    // Opened from the control panel, which `back` returns to
    property bool canGoBack: false
    property bool goingBack: false
    // [{ path, thumb, name }]
    property var walls: []
    // The wallpaper on screen now, to open on
    property string currentPath: ""

    function show(fromMenu) {
        canGoBack = !!fromMenu;
        goingBack = false;
        scan.running = true;
        current.running = true;
        pickCurrent();
        open = true;
        keys.forceActiveFocus();
    }

    function hide() {
        open = false;
    }

    function toggle() {
        open ? hide() : show(false);
    }

    function goBack() {
        goingBack = true;
        hide();
    }

    function pickCurrent() {
        const i = walls.findIndex(w => w.path === currentPath);
        if (i >= 0)
            strip.currentIndex = i;
    }

    function apply(index) {
        const wall = walls[index];
        if (!wall)
            return;
        Quickshell.execDetached(["matugen", "--type", "scheme-expressive", "image", wall.path, "--source-color-index", "0"]);
        hide();
    }

    // Lists the wallpapers, making missing or outdated thumbnails first
    Process {
        id: scan

        command: ["bash", "-c", `
            cache="\${XDG_CACHE_HOME:-$HOME/.cache}/quickbar/wallpapers"
            mkdir -p "$cache"
            for f in "$1"/*; do
                case "\${f,,}" in *.jpg|*.jpeg|*.png|*.webp) ;; *) continue ;; esac
                t="$cache/\${f##*/}.jpg"
                if [ ! -f "$t" ] || [ "$f" -nt "$t" ]; then
                    magick "$f" -strip -thumbnail 480x270^ -gravity center -extent 480x270 -quality 90 "$t" || continue
                fi
                printf '%s\\t%s\\n' "$f" "$t"
            done`, "scan", root.folder]
        stdout: StdioCollector {
            onStreamFinished: {
                const walls = text.split("\n").filter(l => l.includes("\t")).map(l => {
                    const [path, thumb] = l.split("\t");
                    return {
                        path,
                        thumb,
                        name: path.split("/").pop().replace(/\.[^.]+$/, "")
                    };
                });
                if (JSON.stringify(walls) !== JSON.stringify(root.walls)) {
                    root.walls = walls;
                    root.pickCurrent();
                }
            }
        }
    }

    // `awww query`: "…: eDP-1: …, currently displaying: image: <path>"
    Process {
        id: current

        command: ["awww", "query"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/image: (.+)$/m);
                if (m) {
                    root.currentPath = m[1].trim();
                    root.pickCurrent();
                }
            }
        }
    }

    PanelWindow {
        id: window

        property real reveal: 0
        // The pick grows once the panel has sprung open
        property bool settled: false

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
                    window.settled = false;
                    window.visible = true;
                    openAnim.restart();
                } else {
                    openAnim.stop();
                    window.settled = false;
                    closeAnim.restart();
                }
            }
        }

        onVisibleChanged: if (!visible && root.goingBack) {
            root.goingBack = false;
            Panels.controlPanel?.returnFrom("wallpaper");
        }

        NumberAnimation {
            id: openAnim

            target: window
            property: "reveal"
            to: 1
            duration: 320
            easing.type: Easing.OutBack
            easing.overshoot: 0.8
            onFinished: window.settled = true
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

        MouseArea {
            anchors.fill: parent
            onClicked: root.hide()
        }

        Rectangle {
            id: panel

            readonly property real fullHeight: strip.y + strip.height + 6

            // Edge to edge across the middle of the screen, square; it
            // opens out from its centre line
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: Math.max(0, fullHeight * window.reveal)
            color: Theme.surface_container
            clip: true

            MouseArea {
                anchors.fill: parent
            }

            Item {
                id: keys

                // The first g of a gg
                property bool pendingG: false

                Timer {
                    id: gTimer

                    interval: 600
                    onTriggered: keys.pendingG = false
                }

                Keys.onPressed: event => {
                    const g = event.key === Qt.Key_G && event.text === "g";
                    if (!g)
                        pendingG = false;
                    switch (event.key) {
                    case Qt.Key_H:
                    case Qt.Key_K:
                    case Qt.Key_Left:
                    case Qt.Key_Up:
                    case Qt.Key_Backtab:
                        strip.decrementCurrentIndex();
                        break;
                    case Qt.Key_L:
                    case Qt.Key_J:
                    case Qt.Key_Right:
                    case Qt.Key_Down:
                    case Qt.Key_Tab:
                        strip.incrementCurrentIndex();
                        break;
                    case Qt.Key_G:
                        // A capital can come without Shift held (wtype)
                        if (event.text === "G") {
                            strip.currentIndex = strip.count - 1;
                        } else if (pendingG) {
                            pendingG = false;
                            strip.currentIndex = 0;
                        } else {
                            pendingG = true;
                            gTimer.restart();
                        }
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                    case Qt.Key_Space:
                        root.apply(strip.currentIndex);
                        break;
                    case Qt.Key_Backspace:
                        if (!root.canGoBack)
                            return;
                        root.goBack();
                        break;
                    case Qt.Key_Escape:
                        root.canGoBack ? root.goBack() : root.hide();
                        break;
                    case Qt.Key_Q:
                        root.hide();
                        break;
                    default:
                        return;
                    }
                    event.accepted = true;
                }
            }

            // The title, and the pick's name
            Row {
                id: header

                x: 20
                y: 22
                height: 34
                spacing: 4

                IconButton {
                    visible: root.canGoBack
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "chevron"
                    iconSize: 22
                    color: Theme.primary
                    onClicked: root.goBack()
                }

                Label {
                    height: 34
                    verticalAlignment: Text.AlignVCenter
                    text: "Wallpaper"
                    color: Theme.primary
                    font.pixelSize: 26
                    font.weight: Theme.titleWeight
                    roundness: Theme.titleRoundness
                }
            }

            Label {
                anchors.right: parent.right
                anchors.rightMargin: 24
                anchors.verticalCenter: header.verticalCenter
                text: root.walls[strip.currentIndex]?.name ?? ""
                color: Theme.on_surface_variant
                font.pixelSize: 15
            }

            // Tiles laid edge to edge along a straight path as long as the
            // tiles it holds, so there are no gaps; the pick is kept in the
            // middle and the strip loops round
            PathView {
                id: strip

                readonly property int fits: Math.ceil(width / root.tileWidth) + 2

                y: header.y + header.height + 8
                width: parent.width
                // Room above and below for the grown pick
                height: root.tileHeight * root.grownScale + 16
                model: root.walls
                pathItemCount: Math.min(count, fits)
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: 320
                snapMode: PathView.SnapToItem
                interactive: false

                path: Path {
                    startX: strip.width / 2 - strip.pathItemCount * root.tileWidth / 2
                    startY: strip.height / 2

                    PathLine {
                        x: strip.width / 2 + strip.pathItemCount * root.tileWidth / 2
                        y: strip.height / 2
                    }
                }

                WheelHandler {
                    onWheel: event => {
                        if (event.angleDelta.y + event.angleDelta.x > 0)
                            strip.decrementCurrentIndex();
                        else
                            strip.incrementCurrentIndex();
                    }
                }

                delegate: Item {
                    id: tile

                    required property var modelData
                    required property int index
                    readonly property bool isCurrent: PathView.isCurrentItem
                    readonly property bool grown: isCurrent && window.settled

                    width: root.tileWidth
                    height: root.tileHeight
                    z: isCurrent ? 2 : 1
                    scale: grown ? root.grownScale : 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.2
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent
                        radius: picture.radius
                        blur: 24
                        offset.y: 4
                        color: Qt.rgba(0, 0, 0, 0.35)
                        opacity: tile.grown ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.animNormal
                            }
                        }
                    }

                    ClippingRectangle {
                        id: picture

                        anchors.fill: parent
                        // Square edges in the strip; the grown pick rounds
                        radius: tile.grown ? Theme.radius : 0
                        color: Theme.surface_container_high

                        Behavior on radius {
                            NumberAnimation {
                                duration: Theme.animNormal
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.emphasizedDecel
                            }
                        }

                        Image {
                            anchors.fill: parent
                            source: `file://${tile.modelData.thumb}`
                            sourceSize.width: 480
                            sourceSize.height: 270
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                        }

                        // The rest sit back
                        Rectangle {
                            anchors.fill: parent
                            color: "black"
                            opacity: tile.isCurrent ? 0 : 0.4

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.animNormal
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tile.isCurrent ? root.apply(tile.index) : strip.currentIndex = tile.index
                    }
                }
            }
        }
    }

    // `qs -p <dir> ipc call wallpaper toggle`, e.g. from Super+Ctrl+Space
    IpcHandler {
        target: "wallpaper"

        function toggle(): void {
            root.toggle();
        }
    }
}
