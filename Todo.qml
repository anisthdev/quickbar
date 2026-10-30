pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// The to-do list, in ~/Notes/todo.md beside the notes inbox: one task a
// line, "- [ ] text" or "- [x] text" once done, so it reads and edits as
// Markdown anywhere. Other lines (a heading, notes) are kept as they are.
// The clock pill's tasks count (Tasks) and its dropdown (TasksCard) show
// it; changes made elsewhere show at once.
Singleton {
    id: root

    readonly property string path: Quickshell.env("HOME") + "/Notes/todo.md"

    // The file's lines, and the tasks among them: { line, text, done }
    property var lines: []
    readonly property var tasks: lines.map((l, i) => {
            const m = l.match(/^\s*[-*] \[([ xX])\] (.*)$/);
            return m ? {
                line: i,
                text: m[2],
                done: m[1] !== " "
            } : null;
        }).filter(t => t)
    readonly property int left: tasks.filter(t => !t.done).length

    function add(text) {
        const task = text.trim().replace(/\s+/g, " ");
        if (task === "")
            return;
        const next = lines.some(l => l.trim() !== "") ? lines.slice() : ["# To do", ""];
        // After the last task, else at the end
        const after = tasks.length ? tasks[tasks.length - 1].line + 1 : next.length;
        next.splice(after, 0, `- [ ] ${task}`);
        write(next);
    }

    function toggle(task) {
        const next = lines.slice();
        next[task.line] = next[task.line].replace(/\[([ xX])\]/, task.done ? "[ ]" : "[x]");
        write(next);
    }

    function remove(task) {
        const next = lines.slice();
        next.splice(task.line, 1);
        write(next);
    }

    function clearDone() {
        const done = new Set(tasks.filter(t => t.done).map(t => t.line));
        write(lines.filter((_, i) => !done.has(i)));
    }

    function write(next) {
        // A trailing newline, as editors leave
        while (next.length && next[next.length - 1] === "")
            next.pop();
        lines = next;
        file.setText(next.join("\n") + "\n");
    }

    FileView {
        id: file

        path: root.path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const text = file.text();
            root.lines = text.replace(/\n$/, "").split("\n");
        }
        onLoadFailed: root.lines = []
    }

    // `qs -p <dir> ipc call todo add "Buy milk"`
    IpcHandler {
        target: "todo"

        function add(text: string): void {
            root.add(text);
        }
    }
}
