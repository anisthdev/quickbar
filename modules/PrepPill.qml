import Quickshell
import QtQuick
import ".."
import "../components"

// Interview preparation in the bar (PrepState): a code icon; after it the
// problems due for a re-solve today, if any; and while an attempt is timed,
// its clock, in the error colour once past the plan's 35 minutes. Click for
// the dashboard (PrepCard), right-click for the menu (PrepMenu, as Super+D),
// middle-click stops a running timer. Hidden without prep installed, and
// on days off (Settings.showPrep, `qs -c quickbar ipc call prepbar toggle`;
// the menu on Super+D still opens).
Pill {
    id: root

    padding: 9
    spacing: 7
    visible: PrepState.available && Settings.showPrep
    clickable: true
    onClicked: event => {
        if (event.button === Qt.RightButton)
            Panels.prepMenu?.toggle();
        else if (event.button === Qt.MiddleButton && PrepState.timer)
            PrepState.stopTimer();
        else
            card.toggle();
    }

    Icon {
        name: "code"
        size: 18
        color: PrepState.timer ? (PrepState.overTime ? Theme.error : Theme.primary) : Theme.on_background
    }

    // Re-solves due
    Row {
        anchors.verticalCenter: parent.verticalCenter
        visible: PrepState.due.length > 0
        spacing: 3

        Icon {
            name: "restart_alt"
            size: 15
            color: Theme.tertiary_fixed
        }

        RollingText {
            text: PrepState.due.length
            color: Theme.on_background
            fontWeight: Font.Bold
        }
    }

    // The attempt's clock
    Label {
        visible: PrepState.timer !== null
        text: PrepState.clock(PrepState.elapsed)
        color: PrepState.overTime ? Theme.error : Theme.primary
        font.weight: Font.Bold
        font.features: {
            "tnum": 1
        }
    }

    Tooltip {
        owner: root
        shown: root.hovered && !card.open
        text: {
            const p = PrepState.phase;
            return p ? `${p.name} · ${p.daysLeft} days left` : "Prep";
        }
        description: {
            const s = PrepState.status;
            if (!s)
                return "";
            const lines = [];
            if (PrepState.timer)
                lines.push(`Timing ${PrepState.timer.title || "an attempt"}`);
            if (s.phase)
                lines.push(s.phase.metric.label);
            lines.push(`Studied ${s.studiedLast14} of the last 14 days`);
            if (s.due.length)
                lines.push(`Re-solve: ${s.due.map(d => d.title).join(", ")}`);
            return lines.join("\n");
        }
    }

    PrepCard {
        id: card

        owner: root
    }

    // `qs -c quickbar ipc call prepcard toggle`, through BarIpc
    Connections {
        target: BarIpc
        function onToggled(name, monitor) {
            if (name === "prepcard" && monitor === root.QsWindow.window?.screen?.name)
                card.toggle();
        }
    }
}
