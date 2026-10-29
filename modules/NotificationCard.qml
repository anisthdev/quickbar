import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import QtQuick
import ".."
import "../components"

// One heads-up notification, Android 16 style: the app's icon in a circle,
// "App · time" over the title and text, an optional picture on the right, a
// progress bar when the sender reports one (a negative or non-numeric value
// meaning busy with no known end), and actions as text buttons. A sender
// that asks for an inline reply (KDE's extension: an "inline-reply" action)
// gets a Reply button that opens a text field in place of the buttons.
// Clicking runs the default action (or dismisses, without one); swipe it
// sideways to dismiss. It slides in from the right edge and folds away when it goes,
// moving by shape only (see Dropdown on why nothing here fades).
//
// A notification object is destroyed the moment it closes, so everything
// shown is copied out of it first; the card keeps its last look to animate
// away with.
Item {
    id: root

    required property int key
    required property var source
    // Gap to the card above
    property real spacing: 8

    signal finished

    property var n: null
    property string appName
    property string appIcon
    property string summary
    property string body
    property string image
    // 0-100, or -1 without a progress bar
    property int progress: -1
    // Busy, but no telling how far along
    property bool indeterminate: false
    // What the bar shows: glides to each new value over about as long as
    // the sender takes between updates, so steady updates read as one
    // continuous fill rather than a staircase
    property real shownProgress: 0
    property real glide: 0
    property double progressAt: 0

    Behavior on shownProgress {
        enabled: root.glide > 0
        NumberAnimation {
            duration: root.glide
            easing.type: Easing.Linear
        }
    }
    property var actions: []
    property bool critical: false
    property double arrived: Date.now()
    property bool expanded: false
    // Typing a reply, and what became of the last one sent
    property bool replying: false
    property string replyStatus
    property string replyPlaceholder
    // Notifications sharing this hint replace each other (volume and
    // brightness levels from sysaud, the screenshot countdown). Those with
    // a value (the levels) show as a thick pill instead, as Android's
    // volume and brightness sliders look.
    property string syncKey
    property bool hasValue: false
    readonly property bool level: syncKey !== "" && hasValue
    readonly property string levelIcon: {
        if (/bright/i.test(syncKey))
            return shownProgress < 34 ? "brightness_low" : shownProgress < 67 ? "brightness_medium" : "brightness_full";
        return shownProgress > 0 ? "volume" : "volume_mute";
    }

    // 0 = folded away, 1 = fully in
    property real reveal: 0
    property bool leaving: false

    readonly property bool hovered: hover.hovered

    // "now", "5m", "2h"; re-read every minute through the clock
    function ago(time) {
        tick.date;
        const minutes = Math.floor((Date.now() - time) / 60000);
        return minutes < 1 ? "now" : minutes < 60 ? `${minutes}m` : `${Math.floor(minutes / 60)}h`;
    }

    function iconFor(name) {
        if (!name)
            return "";
        if (name.startsWith("/"))
            return `file://${name}`;
        if (name.includes("://"))
            return name;
        return Quickshell.iconPath(name, true);
    }

    // Pango's <span size="small"> (handoff's status line) is the one bit
    // of markup Text's StyledText lacks; newlines become breaks
    function styled(text) {
        return text.replace(/<span size="small">/g, "<small>").replace(/<\/span>/g, "</small>").replace(/\n/g, "<br>");
    }

    function sync() {
        if (!n)
            return;
        // An update restarts the clock, as on Android (only one that's
        // ticking: restart() would also start one meant never to expire)
        arrived = Date.now();
        if (expiry.running)
            expiry.restart();
        const entry = (n.desktopEntry && DesktopEntries.byId(n.desktopEntry)) || DesktopEntries.heuristicLookup(n.appName);
        appName = entry?.name || n.appName || "Notification";
        syncKey = n.hints?.["x-canonical-private-synchronous"] ?? "";
        hasValue = n.hints?.value !== undefined;
        // notify-send -i arrives as a themed "image"; that's the app's icon,
        // not a picture
        const themed = (n.image ?? "").startsWith("image://icon/");
        appIcon = iconFor(n.appIcon) || (themed ? n.image : "") || iconFor(entry?.icon ?? "");
        image = themed ? "" : n.image ?? "";
        summary = n.summary;
        body = styled(n.body);
        const value = n.hints?.value;
        // Negative, or not a number at all (notify-send can't send a
        // negative int, so `-h string:value:busy` does the same)
        indeterminate = value !== undefined && !(Number(value) >= 0);
        const next = value === undefined || indeterminate ? -1 : Math.max(0, Math.min(100, Number(value)));
        if (next !== progress) {
            const now = Date.now();
            // The first value, or a jump back, lands at once
            glide = progress < 0 || next < shownProgress ? 0 : Math.max(150, Math.min(2000, now - progressAt));
            progressAt = now;
            progress = next;
            shownProgress = Math.max(0, next);
        }
        // Reply comes first; Quickshell keeps the reply action out of
        // n.actions and hands its label over as inlineReplyPlaceholder
        const buttons = n.hasInlineReply ? [
            {
                id: "inline-reply",
                text: n.inlineReplyPlaceholder || "Reply"
            }
        ] : [];
        actions = buttons.concat(Array.from(n.actions).filter(a => a.identifier !== "default").map(a => ({
                        id: a.identifier,
                        text: a.text
                    })));
        replyPlaceholder = n.hints?.["x-kde-reply-placeholder-text"] || "Reply";
        // An update from the sender (e.g. the reply went through) replaces
        // the "Sending…" line
        replyStatus = "";
        critical = n.urgency === NotificationUrgency.Critical;
    }

    // Take over from a newer notification of the same kind, keeping the
    // card in place
    function adopt(other) {
        const old = n;
        n = other;
        sync();
        old?.dismiss();
    }

    function invoke(id) {
        if (id === "inline-reply") {
            replying = true;
            return;
        }
        const action = Array.from(n?.actions ?? []).find(a => a.identifier === id);
        if (action)
            action.invoke();
        // Non-resident notifications are done once acted on
        if (n && !n.resident)
            n.dismiss();
    }

    function sendReply(text) {
        if (!n)
            return;
        n.sendInlineReply(text);
        replying = false;
        replyStatus = "Sending…";
    }

    function dismiss() {
        if (n)
            n.dismiss();
        else
            leave(1);
    }

    // direction: 1 slides off to the right, -1 to the left
    function leave(direction) {
        if (leaving)
            return;
        leaving = true;
        slideOff.to = direction * (width + 40);
        leaveAnim.start();
    }

    width: 440
    height: (card.height + spacing) * reveal
    clip: true

    Component.onCompleted: {
        n = source;
        sync();
        enterAnim.start();
    }

    SystemClock {
        id: tick
        precision: SystemClock.Minutes
    }

    Connections {
        target: root.n

        function onSummaryChanged() {
            root.sync();
        }
        function onBodyChanged() {
            root.sync();
        }
        function onHintsChanged() {
            root.sync();
        }
        function onImageChanged() {
            root.sync();
        }
        function onAppIconChanged() {
            root.sync();
        }
        function onActionsChanged() {
            root.sync();
        }
        function onUrgencyChanged() {
            root.sync();
        }
        function onClosed() {
            root.leave(card.x < 0 ? -1 : 1);
        }
    }

    // Milliseconds; -1 asks for the default, 0 for never
    Timer {
        id: expiry

        readonly property real asked: root.n?.expireTimeout ?? -1

        interval: asked > 0 ? asked : 6000
        running: !!root.n && !root.critical && asked !== 0 && !root.hovered && !drag.active && !root.leaving && !root.replying
        onTriggered: root.n?.expire()
    }

    // Unfold, then slide in from the right edge
    ParallelAnimation {
        id: enterAnim

        NumberAnimation {
            target: root
            property: "reveal"
            from: 0
            to: 1
            duration: 260
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasizedDecel
        }
        NumberAnimation {
            target: card
            property: "x"
            from: root.width
            to: 0
            duration: 380
            easing.type: Easing.OutBack
            easing.overshoot: 0.6
        }
    }

    // Slide off, then fold the gap closed
    SequentialAnimation {
        id: leaveAnim

        NumberAnimation {
            id: slideOff

            target: card
            property: "x"
            duration: 180
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasizedAccel
        }
        NumberAnimation {
            target: root
            property: "reveal"
            to: 0
            duration: 200
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasizedDecel
        }
        ScriptAction {
            script: root.finished()
        }
    }

    // Spring back after a short swipe
    NumberAnimation {
        id: springBack

        target: card
        property: "x"
        to: 0
        duration: 300
        easing.type: Easing.OutBack
    }

    Rectangle {
        id: card

        // At the bottom of the space it unfolds, so it rises into place
        y: root.height - height
        width: root.width
        height: root.level ? levelBar.height + 2 * levelBar.x : content.implicitHeight + 32
        radius: Theme.cardRadius
        color: Theme.surface_container

        HoverHandler {
            id: hover
        }

        // Swipe sideways to dismiss
        DragHandler {
            id: drag

            target: card
            yAxis.enabled: false
            enabled: !root.leaving
            onActiveChanged: {
                if (active) {
                    springBack.stop();
                    return;
                }
                if (Math.abs(card.x) > card.width * 0.3)
                    root.n ? root.n.dismiss() : root.leave(card.x < 0 ? -1 : 1);
                else
                    springBack.start();
            }
        }

        // Click: the default action if there is one, else just dismiss
        TapHandler {
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onTapped: (point, button) => {
                if (button === Qt.MiddleButton)
                    root.dismiss();
                else
                    root.invoke("default");
            }
        }

        Row {
            id: content

            visible: !root.level

            x: 16
            y: 16
            width: parent.width - 32
            spacing: 14

            // App icon in a circle; its initial when it has none
            Rectangle {
                width: 44
                height: 44
                radius: 22
                color: root.critical ? Theme.error : Theme.surface_container_highest

                IconImage {
                    anchors.centerIn: parent
                    visible: root.appIcon !== ""
                    source: root.appIcon
                    implicitSize: 28
                }

                Label {
                    anchors.centerIn: parent
                    visible: root.appIcon === ""
                    text: root.appName.charAt(0).toUpperCase()
                    color: root.critical ? Theme.on_error : Theme.on_surface
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }
            }

            Column {
                width: parent.width - 44 - parent.spacing
                spacing: 2

                // App · time, and the buttons
                Item {
                    visible: !root.level
                    width: parent.width
                    height: 22

                    Label {
                        anchors.left: parent.left
                        anchors.right: buttons.left
                        anchors.rightMargin: 8
                        text: `${root.appName} · ${root.ago(root.arrived)}`
                        color: Theme.on_surface_variant
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }

                    Row {
                        id: buttons

                        anchors.right: parent.right
                        anchors.rightMargin: -6
                        anchors.verticalCenter: parent.verticalCenter

                        IconButton {
                            visible: bodyText.truncated || root.expanded
                            implicitWidth: 26
                            implicitHeight: 26
                            icon: "chevron"
                            iconSize: 14
                            iconRotation: root.expanded ? 90 : 270
                            color: Theme.on_surface_variant
                            onClicked: root.expanded = !root.expanded
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: 12

                    Column {
                        width: parent.width - (picture.visible ? picture.width + parent.spacing : 0)
                        spacing: 2

                        Label {
                            anchors.verticalCenter: undefined
                            width: parent.width
                            visible: text !== ""
                            text: root.summary
                            color: Theme.on_surface
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            maximumLineCount: root.expanded ? 3 : 1
                            wrapMode: Text.Wrap
                        }

                        Text {
                            id: bodyText

                            width: parent.width
                            visible: text !== ""
                            text: root.body
                            textFormat: Text.StyledText
                            color: Theme.on_surface_variant
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                            font.weight: Font.Medium
                            lineHeight: 1.1
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                            maximumLineCount: root.expanded ? 12 : 2
                        }
                    }

                    // The sender's picture: a contact, an album, a screenshot
                    ClippingRectangle {
                        id: picture

                        visible: root.image !== ""
                        width: 56
                        height: 56
                        radius: Theme.radius
                        color: Theme.surface_container_highest

                        Image {
                            anchors.fill: parent
                            source: root.image
                            sourceSize: Qt.size(96, 96)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }
                }

                // Progress: wavy for ongoing work, a thick flat bar for levels
                LinearProgress {
                    visible: root.progress >= 0 || root.indeterminate
                    width: parent.width
                    progress: root.shownProgress / 100
                    indeterminate: root.indeterminate
                    wavy: true
                    thickness: 6
                }

                Label {
                    anchors.verticalCenter: undefined
                    visible: root.replyStatus !== ""
                    topPadding: 4
                    text: root.replyStatus
                    color: Theme.primary
                    font.pixelSize: 14
                }

                // Actions as M3 text buttons, as Android lays them out: the
                // label in the accent colour, no container until hovered, the
                // first label lined up with the text above. The reply field
                // takes their place.
                Flow {
                    visible: root.actions.length > 0 && !root.replying
                    x: -12
                    width: parent.width + 12
                    topPadding: 4
                    spacing: 4

                    Repeater {
                        model: root.actions

                        Rectangle {
                            id: action

                            required property var modelData

                            width: actionLabel.implicitWidth + 24
                            height: 40
                            radius: Theme.radius
                            // State layer only
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, actionMouse.pressed ? 0.12 : actionMouse.containsMouse ? 0.08 : 0)

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.animFast
                                }
                            }

                            Label {
                                id: actionLabel

                                anchors.centerIn: parent
                                text: action.modelData.text
                                color: Theme.primary
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                id: actionMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.invoke(action.modelData.id)
                            }
                        }
                    }
                }

                Item {
                    visible: root.replying
                    width: parent.width
                    height: 52

                    EntryField {
                        y: 8
                        width: parent.width
                        inset: 0
                        active: root.replying
                        secret: false
                        placeholder: root.replyPlaceholder
                        buttonText: "Send"
                        onSubmitted: text => root.sendReply(text)
                        onCancelled: root.replying = false
                    }
                }
            }
        }

        // Volume or brightness: a thick level bar like the battery card's,
        // inset in the card so its corners follow the card's, with the icon
        // riding in the filled part and the number on the track
        LevelBar {
            id: levelBar

            visible: root.level
            // cardRadius - radius, so the corners are concentric
            x: Theme.cardRadius - Theme.radius
            y: x
            width: parent.width - 2 * x
            height: 52
            value: Math.max(0, root.progress) / 100
            minFill: height
            color: Theme.inverse_primary
            trackColor: Theme.background

            Icon {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                name: root.levelIcon
                size: 24
                color: Theme.on_surface
            }

            RollingText {
                anchors.right: parent.right
                anchors.rightMargin: 32
                text: String(Math.max(0, root.progress))
                color: Theme.on_surface
                fontSize: 16
                fontWeight: Font.DemiBold
            }
        }
    }
}
