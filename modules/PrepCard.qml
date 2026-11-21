import Quickshell
import QtQuick
import ".."
import "../components"

// The prep pill's dropdown: where the plan stands. The phase, how far into
// it and its exit test against its measure; this week's focus; the last 14
// days as dots; the week's numbers; the problems to re-solve today, and
// the next few coming due.
//
// Keys: j/k (gg/G) move over the re-solves; Enter or t starts the timer on
// one (Enter on the one being timed logs it); l logs it now; a opens the
// menu to log anything; s stops a running timer; q or Esc closes.
Dropdown {
    id: root

    readonly property var s: PrepState.status
    readonly property var phase: s?.phase ?? null
    readonly property var due: PrepState.due
    readonly property var current: due[cursor.currentIndex] ?? null

    menuWidth: 420
    title: phase ? phase.name : "Prep"
    smoothResize: true

    onOpenChanged: {
        cursor.currentIndex = -1;
        if (open)
            PrepState.refresh();
    }

    function menu(fn) {
        root.open = false;
        fn(Panels.prepMenu);
    }

    keyHandler: event => {
        if (keys.handle(event))
            return true;
        if (event.modifiers & Qt.ControlModifier)
            return false;
        switch (event.key) {
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_T:
            if (!current)
                return true;
            if (event.key !== Qt.Key_T && PrepState.timer?.problem === current.problem)
                menu(m => m?.logProblem(current.problem));
            else
                PrepState.startTimer(current.problem);
            return true;
        case Qt.Key_L:
            if (current)
                menu(m => m?.logProblem(current.problem));
            return true;
        case Qt.Key_A:
            menu(m => m?.show(""));
            return true;
        case Qt.Key_S:
            if (PrepState.timer)
                PrepState.stopTimer();
            return true;
        }
        return false;
    }

    RowCursor {
        id: cursor
        count: root.due.length
    }

    ListKeys {
        id: keys
        list: cursor
    }

    // Phase N of 4, days left, and how far through it
    Column {
        id: phaseBox

        width: parent.width
        spacing: 8
        visible: root.phase !== null

        Label {
            anchors.verticalCenter: undefined
            leftPadding: 8
            text: root.phase ? `Phase ${root.phase.index + 1} of ${root.phase.count} · ${root.phase.daysLeft} days left · ${root.s.daysToDeadline} to the deadline` : ""
            color: Theme.on_surface_variant
            font.pixelSize: 13
        }

        LinearProgress {
            x: 8
            width: parent.width - 16
            height: 8
            thickness: 4
            progress: root.phase?.progress ?? 0
            color: Theme.secondary
            trackColor: Theme.secondary_container
        }

        MenuReveal {
            target: phaseBox
            shown: root.open
            index: 1
        }
    }

    Item {
        width: 1
        height: 6
    }

    // The exit test
    Rectangle {
        id: exitBox

        readonly property var metric: root.phase?.metric ?? null

        width: parent.width
        height: exitColumn.implicitHeight + 28
        radius: Theme.radius
        color: Theme.surface_container_high
        visible: metric !== null

        Column {
            id: exitColumn

            x: 14
            y: 14
            width: parent.width - 28
            spacing: 8

            Row {
                spacing: 6

                Icon {
                    name: exitBox.metric?.met ? "task_alt" : "emoji_flags"
                    size: 15
                    color: exitBox.metric?.met ? Theme.tertiary_fixed : Theme.primary
                }

                Label {
                    text: root.phase ? `Exit test · ${Qt.formatDate(new Date(root.phase.end + "T00:00"), "d MMM")}` : ""
                    color: Theme.primary
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }

            Label {
                anchors.verticalCenter: undefined
                width: parent.width
                text: root.phase?.exit ?? ""
                color: Theme.on_surface
                wrapMode: Text.WordWrap
            }

            LinearProgress {
                width: parent.width
                height: 10
                thickness: 6
                progress: exitBox.metric?.progress ?? 0
                color: exitBox.metric?.met ? Theme.tertiary_fixed : Theme.primary
                trackColor: Theme.primary_container
            }

            Label {
                anchors.verticalCenter: undefined
                width: parent.width
                text: exitBox.metric?.label ?? ""
                color: Theme.on_surface_variant
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }

        MenuReveal {
            target: exitBox
            shown: root.open
            index: 2
        }
    }

    Item {
        width: 1
        height: 6
    }

    // This week's focus, from the plan
    Rectangle {
        id: weekBox

        width: parent.width
        height: weekColumn.implicitHeight + 24
        radius: Theme.radius
        color: Theme.surface_container_high
        visible: !!root.s?.week

        Column {
            id: weekColumn

            x: 14
            y: 12
            width: parent.width - 28
            spacing: 4

            Label {
                anchors.verticalCenter: undefined
                text: root.s?.week?.label ?? ""
                color: Theme.primary
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            Label {
                anchors.verticalCenter: undefined
                width: parent.width
                text: {
                    const w = root.s?.week;
                    if (!w)
                        return "";
                    return w.patternNames.length ? `${w.patternNames.join(", ")} · ${w.focus}` : w.focus;
                }
                color: Theme.on_surface
                wrapMode: Text.WordWrap
            }
        }

        MenuReveal {
            target: weekBox
            shown: root.open
            index: 3
        }
    }

    Item {
        width: 1
        height: 6
    }

    // The last 14 days, a dot each, today's ringed
    Item {
        id: stripBox

        width: parent.width
        height: 44

        Row {
            id: dots

            x: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Repeater {
                model: root.s?.strip ?? []

                Rectangle {
                    required property var modelData
                    required property int index

                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    radius: 5
                    color: modelData.studied ? Theme.primary : Theme.surface_container_highest
                    border.width: index === 13 ? 2 : 0
                    border.color: Theme.on_surface
                }
            }
        }

        Label {
            anchors.right: parent.right
            anchors.rightMargin: 8
            text: `${root.s?.studiedLast14 ?? 0} of 14 days`
            color: Theme.on_surface_variant
            font.pixelSize: 13
        }

        MenuReveal {
            target: stripBox
            shown: root.open
            index: 4
        }
    }

    // The week so far
    Row {
        id: tiles

        readonly property var w: root.s?.thisWeek ?? null
        readonly property real tileWidth: (width - 2 * spacing) / 3

        width: parent.width
        spacing: 6

        InfoTile {
            width: tiles.tileWidth
            icon: "code"
            title: "This week"
            value: tiles.w?.problems ?? 0
            unit: "problems"
            caption: tiles.w ? `${tiles.w.solved} ✓  ${tiles.w.hint} ~  ${tiles.w.failed} ✗` : ""
        }

        InfoTile {
            width: tiles.tileWidth
            icon: "schedule"
            title: "Time"
            value: tiles.w ? (tiles.w.minutes / 60).toFixed(1) : "0"
            unit: "h"
            caption: tiles.w ? `on ${tiles.w.days} days` : ""
        }

        InfoTile {
            width: tiles.tileWidth
            icon: "checklist"
            title: "NeetCode 150"
            value: root.s?.totals.listSolved ?? 0
            unit: `/ ${root.s?.totals.listTotal ?? 150}`
            caption: `${root.s?.totals.mocksPassed ?? 0}/${root.s?.totals.mocks ?? 0} mocks passed`
        }

        MenuReveal {
            target: tiles
            shown: root.open
            index: 5
        }
    }

    // Re-solves due today
    Label {
        anchors.verticalCenter: undefined
        visible: root.due.length > 0
        leftPadding: 8
        topPadding: 14
        bottomPadding: 6
        text: `Re-solve today · ${root.due.length}`
        color: Theme.on_surface_variant
        font.pixelSize: 13
    }

    Repeater {
        model: root.due

        ListItem {
            required property var modelData
            required property int index
            readonly property bool timing: PrepState.timer?.problem === modelData.problem

            icon: timing ? "timer" : "restart_alt"
            text: modelData.title
            subtitle: {
                const late = modelData.overdueDays ? ` · ${modelData.overdueDays} d late` : "";
                return `${modelData.last === "fail" ? "Failed" : "Hints"} on ${Qt.formatDate(new Date(modelData.lastDate + "T00:00"), "d MMM")}${late}`;
            }
            first: index === 0
            last: index === root.due.length - 1
            clickable: true
            highlighted: cursor.currentIndex === index
            shown: root.open
            revealIndex: 6 + index
            onClicked: timing ? root.menu(m => m?.logProblem(modelData.problem)) : PrepState.startTimer(modelData.problem)

            Label {
                text: timing ? PrepState.clock(PrepState.elapsed) : modelData.diff
                color: timing ? (PrepState.overTime ? Theme.error : Theme.primary) : Theme.on_surface_variant
                font.pixelSize: 12
                font.weight: timing ? Font.Bold : Font.Medium
            }
        }
    }

    // Coming due
    Label {
        id: upcoming

        readonly property var next: (root.s?.upcoming ?? []).slice(0, 3)

        anchors.verticalCenter: undefined
        visible: next.length > 0
        width: parent.width
        leftPadding: 8
        topPadding: 12
        text: "Coming up: " + next.map(d => `${d.title} (${Qt.formatDate(new Date(d.retry + "T00:00"), "ddd")})`).join(", ")
        color: Theme.on_surface_variant
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }

    // Nothing due and nothing logged yet today
    Label {
        anchors.verticalCenter: undefined
        visible: root.due.length === 0 && !(root.s?.studiedToday ?? true)
        width: parent.width
        leftPadding: 8
        topPadding: 12
        text: "Nothing due. One problem today is enough."
        color: Theme.on_surface_variant
        font.pixelSize: 13
    }

    // The keys
    Label {
        anchors.verticalCenter: undefined
        width: parent.width
        leftPadding: 8
        topPadding: 12
        text: root.due.length ? "t timer · l log · a menu · s stop timer" : "a menu · s stop timer · right-click the pill for the menu"
        color: Theme.outline
        font.pixelSize: 11
    }
}
