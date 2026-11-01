import Quickshell
import QtQuick
import ".."
import "../components"

// The to-do half of the clock pill (see Glance), after the time and the
// timer: how many tasks are left on the list (Todo), hidden when there are
// none. Click for the to-do dropdown (TasksCard); hover for the next few.
Pill {
    id: root

    padding: 8
    implicitHeight: Theme.barHeight - 10
    anchors.verticalCenter: parent?.verticalCenter
    radius: 8
    color: "transparent"
    // Kept while its dropdown is open, so ticking off the last task
    // doesn't take the dropdown's anchor away
    visible: Todo.left > 0 || card.open
    clickable: true
    onClicked: card.toggle()

    RollingText {
        text: Todo.left
        color: Theme.on_background
        fontWeight: Font.Bold
    }

    Tooltip {
        owner: root
        shown: root.hovered && !card.open
        text: Todo.left === 1 ? "1 task to do" : `${Todo.left} tasks to do`
        description: {
            const left = Todo.tasks.filter(t => !t.done);
            const next = left.slice(0, 3).map(t => `• ${t.text}`);
            if (left.length > 3)
                next.push(`and ${left.length - 3} more`);
            return next.join("\n");
        }
    }

    TasksCard {
        id: card
        owner: root
    }

    // `qs -c quickbar ipc call tasks toggle`, through BarIpc: only the bar on
    // the focused monitor opens it, showing the count first if it's hidden
    Connections {
        target: BarIpc
        function onToggled(name, monitor) {
            if (name === "tasks" && monitor === root.QsWindow.window?.screen?.name)
                card.toggle();
        }
    }
}
