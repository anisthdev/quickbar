import QtQuick
import "../.."
import "../../components"
import "Languages.js" as Languages

// The languages a title plays in, in a card over the video menu: Audio and
// Subtitles side by side, each Automatic (mpv's own choice, by mpv.conf's
// alang and slang) or one of the title's languages, subtitles Off too.
// h/l (Tab) go between them, j/k move, Enter or Space keeps the choice, Esc
// or q leaves it as it was. The choice is the title's, for every episode.
Item {
    id: root

    property bool open: false
    property string title
    property var audio: []
    property var subs: []
    // The columns' options: codes, "" for Automatic, "no" for Off
    readonly property var options: [[""].concat(audio), ["", "no"].concat(subs)]
    property int column: 0
    property var picks: [0, 0]
    property var onPick: null

    signal finished

    // `chosen` (audio, subs) is called with the codes if it's kept
    function ask(name, audioCodes, subCodes, current, chosen) {
        title = name;
        audio = audioCodes;
        subs = subCodes;
        onPick = chosen;
        column = 0;
        picks = [Math.max(0, options[0].indexOf(current?.audio ?? "")), Math.max(0, options[1].indexOf(current?.subs ?? ""))];
        open = true;
        keys.forceActiveFocus();
    }

    function close(keep) {
        open = false;
        if (keep && onPick)
            onPick(options[0][picks[0]], options[1][picks[1]]);
        onPick = null;
        finished();
    }

    function move(by) {
        const p = picks.slice();
        p[column] = Math.max(0, Math.min(options[column].length - 1, p[column] + by));
        picks = p;
    }

    anchors.fill: parent
    visible: open || scrim.opacity > 0

    Item {
        id: keys

        property bool pendingG: false

        Keys.onPressed: event => {
            event.accepted = true;
            const t = event.text;
            if (t !== "g")
                pendingG = false;
            if (event.key === Qt.Key_Escape || t === "q")
                root.close(false);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || t === " ")
                root.close(true);
            else if (t === "j" || event.key === Qt.Key_Down)
                root.move(1);
            else if (t === "k" || event.key === Qt.Key_Up)
                root.move(-1);
            else if (t === "G")
                root.move(999);
            else if (t === "g") {
                if (pendingG)
                    root.move(-999);
                pendingG = !pendingG;
            } else if (t === "h" || event.key === Qt.Key_Left || event.key === Qt.Key_Backtab)
                root.column = 0;
            else if (t === "l" || event.key === Qt.Key_Right || event.key === Qt.Key_Tab)
                root.column = 1;
        }
    }

    Rectangle {
        id: scrim

        anchors.fill: parent
        radius: Theme.cardRadius
        color: Qt.rgba(0, 0, 0, 0.45)
        opacity: root.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animFast
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close(false)
        }
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 560)
        height: Math.min(parent.height - 48, 96 + 2 + 8 * 40 + 56)
        radius: 28
        color: Qt.alpha(Theme.surface_container_high, 1)
        opacity: scrim.opacity
        scale: 0.94 + 0.06 * scrim.opacity
        clip: true

        MouseArea {
            anchors.fill: parent
        }

        Column {
            x: 24
            y: 22
            width: parent.width - 48
            spacing: 2

            Label {
                anchors.verticalCenter: undefined
                text: "Languages"
                color: Theme.on_surface
                font.pixelSize: 22
                font.weight: Font.Normal
                roundness: Theme.titleRoundness
            }

            Label {
                anchors.verticalCenter: undefined
                width: parent.width
                text: root.title
                color: Theme.on_surface_variant
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        Row {
            x: 16
            y: 84
            width: parent.width - 32
            height: parent.height - y - 52
            spacing: 8

            Repeater {
                model: ["Audio", "Subtitles"]

                Column {
                    id: col

                    required property string modelData
                    required property int index
                    readonly property bool active: index === root.column

                    width: (parent.width - 8) / 2
                    height: parent.height
                    spacing: 6

                    Label {
                        anchors.verticalCenter: undefined
                        leftPadding: 10
                        text: col.modelData
                        color: col.active ? Theme.primary : Theme.on_surface_variant
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    ListView {
                        id: options

                        width: parent.width
                        height: parent.height - 24
                        model: root.options[col.index]
                        currentIndex: root.picks[col.index]
                        spacing: 2
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        highlightRangeMode: ListView.ApplyRange
                        preferredHighlightBegin: 0
                        preferredHighlightEnd: height

                        delegate: Rectangle {
                            id: option

                            required property string modelData
                            required property int index
                            readonly property bool picked: index === root.picks[col.index]

                            width: options.width
                            height: 38
                            radius: Theme.radius
                            color: picked ? (col.active ? Theme.secondary_container : Qt.alpha(Theme.secondary_container, 0.45)) : optionMouse.containsMouse ? Theme.surface_container_highest : "transparent"

                            Label {
                                x: 14
                                text: Languages.name(option.modelData)
                                color: option.picked ? Theme.on_secondary_container : Theme.on_surface
                                font.pixelSize: 13
                            }

                            Label {
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                visible: option.modelData !== "" && option.modelData !== "no"
                                text: option.modelData
                                color: option.picked ? Theme.on_secondary_container : Theme.on_surface_variant
                                font.family: Theme.monoFamily
                                font.pixelSize: 11
                            }

                            MouseArea {
                                id: optionMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.column = col.index;
                                    const p = root.picks.slice();
                                    p[col.index] = option.index;
                                    root.picks = p;
                                }
                                onDoubleClicked: root.close(true)
                            }
                        }
                    }
                }
            }
        }

        Label {
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            anchors.verticalCenter: undefined
            text: "h l  between    j k  move    Enter  keep    Esc  leave"
            color: Theme.on_surface_variant
            font.pixelSize: 11
        }
    }
}
