import QtQuick
import Quickshell.Widgets
import "../.."
import "../../components"
import "Plan.js" as Plan

// One of the big cards across the top of the video window's home: the
// title's backdrop over the card's right, fading left into a card of its
// own colours (Tint), and over that its logo (or name), scores, what it is,
// a few lines of its story, Play and the corner figure (how long's left,
// the episode up next, its score). The picked card wears an accent ring.
Item {
    id: root

    property var item
    property bool focused: false
    property bool live: true
    readonly property Tint tint: Tint {
        dark: true
        source: root.live ? root.item?.backdrop ?? "" : ""
    }
    readonly property var figure: item ? Plan.figure(item, Config.reelRatings) : ["", ""]
    readonly property var ratings: {
        const r = item?.ratings ?? {};
        return (Config.reelRatings ?? []).filter(k => r[k]).map(k => ({
                    source: k,
                    score: r[k]
                }));
    }

    signal clicked
    signal activated
    signal play

    ClippingRectangle {
        id: card

        anchors.fill: parent
        radius: 24
        color: root.tint.glow

        Image {
            id: backdrop

            anchors.right: parent.right
            width: parent.width * 0.7
            height: parent.height
            source: root.live && root.item?.backdrop ? `file://${root.item.backdrop}` : ""
            sourceSize.width: 1280
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: status === Image.Ready ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animNormal
                }
            }

            // Into the card's colour, leftwards and down
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: root.tint.glow
                    }
                    GradientStop {
                        position: 0.45
                        color: Qt.alpha(root.tint.glow, 0.55)
                    }
                    GradientStop {
                        position: 0.8
                        color: "transparent"
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height * 0.4
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 1
                        color: Qt.alpha(root.tint.glow, 0.85)
                    }
                }
            }
        }

        Column {
            id: info

            x: 36
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 30
            width: Math.min(parent.width * 0.5, 520)
            spacing: 12

            // The logo where it has one, else the name
            Item {
                id: titleBox

                readonly property real aspect: root.item?.logo_size?.[1] > 0 ? root.item.logo_size[0] / root.item.logo_size[1] : 0
                readonly property real logoHeight: aspect > 0 ? Math.min(root.height > 380 ? 104 : 76, Math.min(parent.width, 360) / aspect) : 0
                readonly property bool logo: !!root.item?.logo_image && aspect > 0 && logoImage.status !== Image.Error

                width: parent.width
                height: logo ? logoHeight : nameText.implicitHeight

                Image {
                    id: logoImage

                    anchors.bottom: parent.bottom
                    visible: titleBox.logo
                    height: titleBox.logoHeight
                    width: height * titleBox.aspect
                    source: root.live && root.item?.logo_image ? `file://${root.item.logo_image}` : ""
                    sourceSize.height: height * 2
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                }

                Label {
                    id: nameText

                    anchors.verticalCenter: undefined
                    anchors.bottom: parent.bottom
                    visible: !titleBox.logo
                    width: parent.width
                    text: root.item?.title ?? ""
                    color: "white"
                    font.pixelSize: 34
                    font.weight: Theme.titleWeight
                    roundness: Theme.titleRoundness
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            // Scores, then what it is
            Row {
                spacing: 16

                Repeater {
                    model: root.ratings

                    RatingBadge {
                        required property var modelData

                        source: modelData.source
                        score: modelData.score
                    }
                }

                Label {
                    text: Plan.facts(root.item, 2)
                    color: Qt.rgba(1, 1, 1, 0.75)
                    font.pixelSize: 13
                }
            }

            Label {
                anchors.verticalCenter: undefined
                width: parent.width
                visible: root.height > 340 && text !== ""
                text: root.item?.overview ?? ""
                color: Qt.rgba(1, 1, 1, 0.82)
                font.pixelSize: 13
                font.weight: Font.Normal
                wrapMode: Text.WordWrap
                maximumLineCount: root.height > 440 ? 3 : 2
                elide: Text.ElideRight
                lineHeight: 1.2
            }

            // Play, and the figure beside it
            Row {
                topPadding: 4
                spacing: 22

                Rectangle {
                    id: playButton

                    width: playRow.implicitWidth + 40
                    height: 46
                    radius: 23
                    color: root.focused || playMouse.containsMouse ? root.tint.accent : Qt.rgba(1, 1, 1, 0.14)

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.animFast
                        }
                    }

                    Row {
                        id: playRow

                        anchors.centerIn: parent
                        spacing: 8

                        Icon {
                            name: "media_play_arrow"
                            size: 22
                            color: root.focused || playMouse.containsMouse ? root.tint.onAccent : "white"
                        }

                        Label {
                            text: Plan.label(root.item)
                            color: root.focused || playMouse.containsMouse ? root.tint.onAccent : "white"
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }

                        Label {
                            visible: root.focused
                            text: "p"
                            color: root.tint.onAccent
                            opacity: 0.6
                            font.family: Theme.monoFamily
                            font.pixelSize: 12
                        }
                    }

                    MouseArea {
                        id: playMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.play()
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter

                    Label {
                        anchors.verticalCenter: undefined
                        text: root.figure[0].toUpperCase()
                        color: Qt.rgba(1, 1, 1, 0.6)
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                    }

                    Label {
                        anchors.verticalCenter: undefined
                        text: root.figure[1]
                        color: root.tint.accent
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
    }

    // The pick's ring
    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: card.radius + 4
        color: "transparent"
        border.width: 3
        border.color: root.tint.accent
        opacity: root.focused ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animFast
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onDoubleClicked: root.activated()
    }
}
