import QtQuick
import ".."
import "../components"

// How many tasks are left on the to-do list (Todo): a checklist and the
// count, hidden when there are none. Click for the to-do menu (TasksMenu);
// hover for the next few.
Pill {
    id: root

    padding: 8
    spacing: 6
    visible: Todo.left > 0
    clickable: true
    onClicked: Panels.tasks?.toggle()

    Icon {
        name: "checklist"
        size: 18
        color: Theme.on_background
    }

    RollingText {
        text: Todo.left
        color: Theme.on_background
        fontWeight: Font.DemiBold
    }

    Tooltip {
        owner: root
        shown: root.hovered
        text: Todo.left === 1 ? "1 task to do" : `${Todo.left} tasks to do`
        description: {
            const left = Todo.tasks.filter(t => !t.done);
            const next = left.slice(0, 3).map(t => `• ${t.text}`);
            if (left.length > 3)
                next.push(`and ${left.length - 3} more`);
            return next.join("\n");
        }
    }
}
