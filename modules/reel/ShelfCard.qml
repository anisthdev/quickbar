import QtQuick
import Quickshell.Widgets
import "../.."
import "../../components"
import "Plan.js" as Plan

// A title on a shelf of the video window's home, in one of three shapes:
//   poster    its poster (2:3), its name and where it's at under it
//   wide      Continue watching: 16:9, the episode up next's still (or the
//             backdrop) with the title's logo, how far along; the episode
//             (or the name) and how long's left under it
//   backdrop  16:9, the backdrop with the logo over its foot
// Picked, it grows a little and takes an accent ring, as a TV's cards do.
// A corner badge says what the shelf wants said (New, S03E02, a score).
Item {
    id: root

    property var item
    property string kind: "poster"
    property bool focused: false
    property color accent: Theme.primary
    property string badge
    property bool live: true

    readonly property bool series: item?.kind === "series"
    readonly property var next: series && item.next >= 0 ? item.episodes[item.next] : null
    readonly property bool watched: item ? Plan.seenAll(item) : false
    // 0 to 1: a movie's position; a series', the episode under way's (wide)
    // or how much of it's been seen
    readonly property real progress: {
        const i = item;
        if (!i || watched)
            return 0;
        if (i.kind === "movie")
            return i.progress;
        if (kind === "wide")
            return next?.progress ?? 0;
        const done = i.episodes.filter(e => e.watched).length;
        return (done + (next?.progress ?? 0)) / Math.max(1, i.episodes.length);
    }
    readonly property real pictureHeight: kind === "poster" ? width * 1.5 : width * 9 / 16
    readonly property string picture: {
        const i = item;
        if (!i)
            return "";
        if (kind === "poster")
            return i.poster ?? "";
        if (kind === "wide" && next?.still)
            return next.still;
        return i.backdrop ?? i.poster ?? "";
    }
    readonly property string line1: {
        if (kind === "wide" && series && next)
            return `${Plan.code(next)}  ·  ${next.title}`;
        return item?.title ?? "";
    }
    readonly property string line2: {
        const i = item;
        if (!i)
            return "";
        if (i.kind === "movie" && i.position > 0)
            return `${Plan.runtime(i.duration - i.position)} left`;
        if (kind === "wide" && next?.position > 0)
            return `${Plan.runtime(next.duration - next.position)} left`;
        if (kind === "wide")
            return i.title;
        if (series && i.started && next)
            return `${Plan.code(next)}  ·  ${i.next + 1} of ${i.episodes.length}`;
        return Plan.facts(i).split("  ·  ").slice(1).join("  ·  ");
    }

    signal clicked
    signal activated

    implicitHeight: pictureHeight + (kind === "backdrop" ? 0 : 50)

    Item {
        id: frame

        width: root.width
        height: root.pictureHeight
        scale: root.focused ? 1.06 : mouse.containsMouse ? 1.02 : 1
        z: 1

        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        ClippingRectangle {
            id: box

            anchors.fill: parent
            radius: root.kind === "poster" ? 12 : 16
            color: Theme.surface_container_highest

            // No picture: the title, in its place
            Label {
                anchors.verticalCenter: undefined
                anchors.fill: parent
                anchors.margins: 12
                visible: art.status !== Image.Ready && root.kind === "poster"
                text: root.item?.title ?? ""
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.Wrap
                color: Theme.on_surface_variant
                font.pixelSize: 15
                font.weight: Theme.titleWeight
            }

            Image {
                id: art

                anchors.fill: parent
                source: root.live && root.picture ? `file://${root.picture}` : ""
                sourceSize.width: Math.ceil(root.width * 2)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                mipmap: true
                opacity: status === Image.Ready ? (root.watched && root.kind !== "poster" ? 0.6 : 1) : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animNormal
                    }
                }
            }

            // Darkens the foot, for the logo and the bar
            Rectangle {
                visible: root.kind !== "poster" || root.progress > 0
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: root.kind === "poster" ? 36 : parent.height * 0.6
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 1
                        color: Qt.rgba(0, 0, 0, 0.72)
                    }
                }
            }

            // The logo where it has one, else the name
            Item {
                visible: root.kind !== "poster"
                x: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.progress > 0 ? 18 : 12
                width: parent.width * 0.55
                height: root.kind === "wide" ? 32 : 40

                readonly property real aspect: root.item?.logo_size?.[1] > 0 ? root.item.logo_size[0] / root.item.logo_size[1] : 0

                Image {
                    id: logo

                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    width: parent.aspect > 0 ? Math.min(parent.width, parent.height * parent.aspect) : parent.width
                    height: parent.aspect > 0 ? width / parent.aspect : parent.height
                    visible: parent.visible && !!root.item?.logo_image
                    source: visible && root.live ? `file://${root.item.logo_image}` : ""
                    sourceSize.height: 96
                    fillMode: Image.PreserveAspectFit
                    horizontalAlignment: Image.AlignLeft
                    verticalAlignment: Image.AlignBottom
                    asynchronous: true
                    smooth: true
                }

                Label {
                    anchors.verticalCenter: undefined
                    anchors.bottom: parent.bottom
                    width: root.width - 24
                    visible: logo.status !== Image.Ready
                    text: root.item?.title ?? ""
                    color: "white"
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }
            }

            // How far it's been watched
            Rectangle {
                visible: root.progress > 0
                x: 10
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                width: parent.width - 20
                height: 4
                radius: 2
                color: Qt.rgba(1, 1, 1, 0.3)

                Rectangle {
                    width: Math.max(height, parent.width * Math.min(1, root.progress))
                    height: parent.height
                    radius: 2
                    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 1)
                }
            }
        }

        // Seen, or the episode a series is up to
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 8
            visible: root.watched || (root.kind === "poster" && root.series && root.item.started && root.next !== null)
            width: chipRow.implicitWidth + 14
            height: 22
            radius: 11
            color: root.watched ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 1) : Qt.rgba(0, 0, 0, 0.6)

            Row {
                id: chipRow

                anchors.centerIn: parent
                spacing: 3

                Icon {
                    visible: root.watched
                    name: "task_alt"
                    size: 13
                    color: Qt.rgba(Theme.on_primary.r, Theme.on_primary.g, Theme.on_primary.b, 1)
                }

                Label {
                    text: root.watched ? "Seen" : root.next ? Plan.code(root.next) : ""
                    color: root.watched ? Qt.rgba(Theme.on_primary.r, Theme.on_primary.g, Theme.on_primary.b, 1) : "white"
                    font.family: root.watched ? Theme.fontFamily : Theme.monoFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }
        }

        // What the shelf says about it
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 8
            visible: root.badge !== ""
            width: badgeLabel.implicitWidth + 12
            height: 22
            radius: 8
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 1)

            Label {
                id: badgeLabel

                anchors.centerIn: parent
                text: root.badge
                color: 0.2126 * root.accent.r + 0.7152 * root.accent.g + 0.0722 * root.accent.b > 0.5 ? "black" : "white"
                font.pixelSize: 11
                font.weight: Font.Bold
            }
        }

        // The pick's ring
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: box.radius + 4
            color: "transparent"
            border.width: 3
            border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 1)
            opacity: root.focused ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animFast
                }
            }
        }
    }

    Column {
        visible: root.kind !== "backdrop"
        anchors.top: frame.bottom
        anchors.topMargin: 10
        x: 2
        width: root.width - 4
        spacing: 1

        Label {
            anchors.verticalCenter: undefined
            width: parent.width
            text: root.line1
            color: root.focused ? Theme.on_surface : Qt.alpha(Theme.on_surface, 0.85)
            font.pixelSize: 13
            font.weight: root.focused ? Font.DemiBold : Font.Medium
            elide: Text.ElideRight
        }

        Label {
            anchors.verticalCenter: undefined
            width: parent.width
            text: root.line2
            color: Theme.on_surface_variant
            font.pixelSize: 11
            font.weight: Font.Normal
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onDoubleClicked: root.activated()
    }
}
