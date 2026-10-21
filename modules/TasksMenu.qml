import Quickshell
import Quickshell.Io
import QtQuick
import ".."
import "../components"

// The to-do list as one of the rofi-shaped menus, beside Quick note: the
// tasks (Todo, in ~/Notes/todo.md), the ones left first, and a field to add
// more. The bar's tasks pill (Tasks) opens it, and so does its key.
//
// Keys: j/k (gg/G, Ctrl+d/u) move, Enter or Space ticks a task or unticks
// it, d deletes it, c clears the done ones, a adds: type the task and
// Enter, the field staying for the next one, Esc back to the list. / or i
// filters, q or Esc closes. Opened with nothing to do, it opens adding.
Scope {
    id: root

    readonly property string icons: Quickshell.shellDir + "/icons"
    property bool adding: false

    // The ones left first, each kept in its place in the file otherwise
    readonly property var entries: Todo.tasks.filter(t => !t.done).concat(Todo.tasks.filter(t => t.done)).map(t => ({
                key: `${t.line}:${t.text}`,
                label: t.text,
                subtitle: t.done ? "Done" : "",
                icon: `${root.icons}/${t.done ? "check_box" : "check_box_outline_blank"}.svg`,
                task: t
            }))

    function toggle() {
        if (menu.open) {
            menu.hide();
            return;
        }
        menu.show();
        add(Todo.left === 0 && Todo.tasks.length === 0);
    }

    function add(on) {
        adding = on;
        menu.prompt = on ? "A new task…" : "";
    }

    Component.onCompleted: Panels.tasks = root
    Component.onDestruction: if (Panels.tasks === root)
        Panels.tasks = null

    LauncherWindow {
        id: menu

        title: root.adding ? "Add a task" : Todo.left > 0 ? `To do · ${Todo.left} left` : "To do"
        placeholder: "Filter the tasks…"
        promptSecret: false
        fieldIcon: root.adding ? "add" : "search"
        fieldAtBottom: root.adding
        closeOnPick: false
        maxRows: 8
        entryKey: "key"
        entries: root.entries
        extraKeys: event => {
            if (event.modifiers & Qt.ControlModifier)
                return false;
            switch (event.key) {
            case Qt.Key_Space:
                if (menu.currentEntry)
                    Todo.toggle(menu.currentEntry.task);
                return true;
            case Qt.Key_D:
                if (menu.currentEntry)
                    Todo.remove(menu.currentEntry.task);
                return true;
            case Qt.Key_C:
                Todo.clearDone();
                return true;
            case Qt.Key_A:
                root.add(true);
                return true;
            }
            return false;
        }
        onActivated: entry => Todo.toggle(entry.task)
        onSubmitted: text => {
            Todo.add(text);
            menu.clearField();
        }
        // Esc while adding: back to the list, or out if there's none
        onPromptCancelled: {
            if (Todo.tasks.length === 0)
                menu.hide();
            root.add(false);
        }
        onOpenChanged: if (!open)
            root.add(false)
    }

    // `qs -p <dir> ipc call tasks toggle`, e.g. from Super+Shift+T
    IpcHandler {
        target: "tasks"

        function toggle(): void {
            root.toggle();
        }
    }
}
