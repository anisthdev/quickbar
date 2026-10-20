import Quickshell.Widgets
import QtQuick
import ".."

// One row of a Material 3 Expressive grouped list, as in Android 16's quick
// settings dialogs: rows of a group share round outer corners and have
// tight corners between them. A selected row fills with the primary colour
// and rounds all its corners. Children go on the right (battery, check
// mark...); `extra` holds content that slides open below the row while
// `expanded`. Rows stagger in with their menu through `shown`/`revealIndex`.
Rectangle {
    id: root

    // Leading icon: `icon` names one of ours, drawn in a tinted badge;
    // `image` is any image (an app's own icon) shown as is. Neither gives a
    // text-only row.
    property string icon
    property string image
    property string text
    property string subtitle
    property real iconSize: 20
    property real imageSize: 20
    property bool first: false
    property bool last: false
    property bool selected: false
    // The keyboard's pick in a list you move through: drawn like hover,
    // plus a focus ring (Material's keyboard focus) unless `focusRing` is
    // off, as in lists that always have one row picked
    property bool highlighted: false
    property bool focusRing: true
    readonly property alias hovered: mouse.containsMouse
    property bool clickable: false
    property bool expanded: false
    // Entrance with the menu, see MenuReveal
    property bool shown: true
    property int revealIndex: 0
    default property alias trailing: trailingRow.data
    property alias extra: extraArea.data

    signal clicked

    property real rowHeight: 56
    // Eases height changes (opening `extra`); off where the owner animates
    // rowHeight itself, or the two would chase each other
    property bool animateHeight: true
    property real outerRadius: Theme.radius
    // Android: 4dp on 72dp rows, so about 3 on these 56px rows
    readonly property real innerRadius: 3
    // Not readonly, so the corner changes can animate
    property real topCorners: selected || first ? outerRadius : innerRadius
    property real bottomCorners: selected || last ? outerRadius : innerRadius

    width: parent?.width ?? 0
    height: rowHeight + (expanded ? extraArea.childrenRect.height : 0)
    clip: true
    topLeftRadius: topCorners
    topRightRadius: topCorners
    bottomLeftRadius: bottomCorners
    bottomRightRadius: bottomCorners
    color: selected ? Theme.primary_container : (highlighted || clickable && mouse.containsMouse) && !expanded ? Theme.surface_container_highest : Theme.surface_container_high

    Behavior on height {
        enabled: root.animateHeight
        NumberAnimation {
            duration: Theme.animNormal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasizedDecel
        }
    }
    Behavior on topCorners {
        NumberAnimation {
            duration: Theme.animNormal
            easing.type: Easing.OutCubic
        }
    }
    Behavior on bottomCorners {
        NumberAnimation {
            duration: Theme.animNormal
            easing.type: Easing.OutCubic
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: Theme.animNormal
        }
    }

    MouseArea {
        id: mouse

        width: parent.width
        height: root.rowHeight
        enabled: root.clickable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Rectangle {
        id: badge

        visible: root.icon !== ""
        x: 10
        y: (root.rowHeight - height) / 2
        width: 36
        height: 36
        radius: Theme.radius
        color: root.selected ? Theme.primary : Theme.primary_container

        Behavior on color {
            ColorAnimation {
                duration: Theme.animNormal
            }
        }

        Icon {
            anchors.centerIn: parent
            name: root.icon
            size: root.iconSize
            color: root.selected ? Theme.on_primary : Theme.on_primary_container
        }
    }

    IconImage {
        id: image

        x: 18
        y: (root.rowHeight - height) / 2
        visible: root.image !== ""
        source: root.image
        implicitSize: root.imageSize
    }

    Column {
        anchors.left: badge.visible ? badge.right : image.visible ? image.right : parent.left
        anchors.leftMargin: badge.visible || image.visible ? 12 : 18
        anchors.right: trailingRow.left
        anchors.rightMargin: 12
        y: (root.rowHeight - height) / 2

        Label {
            anchors.verticalCenter: undefined
            width: parent.width
            text: root.text
            color: root.selected ? Theme.on_primary_container : Theme.on_surface
            elide: Text.ElideRight
        }

        Label {
            anchors.verticalCenter: undefined
            width: parent.width
            visible: text !== ""
            text: root.subtitle
            color: root.selected ? Theme.on_primary_container : Theme.on_surface_variant
            opacity: root.selected ? 0.8 : 1
            font.pixelSize: 12
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
    }

    Row {
        id: trailingRow

        anchors.right: parent.right
        anchors.rightMargin: 16
        y: (root.rowHeight - height) / 2
        spacing: 8
    }

    Item {
        id: extraArea

        y: root.rowHeight
        width: parent.width
        height: childrenRect.height
    }

    // Focus ring
    Rectangle {
        anchors.fill: parent
        visible: root.highlighted && root.focusRing
        color: "transparent"
        border.width: 2
        border.color: root.selected ? Theme.on_primary_container : Theme.primary
        topLeftRadius: root.topCorners
        topRightRadius: root.topCorners
        bottomLeftRadius: root.bottomCorners
        bottomRightRadius: root.bottomCorners
    }

    MenuReveal {
        target: root
        shown: root.shown
        index: root.revealIndex
    }
}
