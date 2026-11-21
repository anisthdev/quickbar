import Quickshell
import Quickshell.Io
import QtQuick
import "../components"
import ".."

// The prep menu (Super+D; right-click on the prep pill): everything that
// goes into `prep`, in pages. The first page: log a problem, time an
// attempt, log study time, a mock interview or a contest, the patterns,
// the application pipeline, the behavioural stories, undo.
//
// Logging a problem: pick it (typing filters; the re-solves due come first,
// then this week's patterns; a name or LeetCode URL not on the list makes a
// new one, which asks its pattern and difficulty), then how it went: s
// solved clean, h with hints, f failed (or pick the row). The running
// timer gives the minutes; without one it asks, and Enter on nothing skips.
//
// Keys as every launcher menu: j/k, gg/G, Enter or l, / to filter, h,
// Backspace or Esc back, q closes. On the applications page n sets the
// next step of the company picked.
Scope {
    id: root

    property string page: ""
    property var stack: []
    // What "problem" picks for: "log" or "timer"
    property string mode: "log"
    // The browse page's pattern, narrowing the problem page
    property string onlyPattern: ""
    // The attempt being logged: { problem, title, isNew, pattern, diff }
    property var draft: null
    // The mock's kind, and the company a stage or next step is for
    property string mockKind: ""
    property string company: ""

    readonly property var s: PrepState.status
    readonly property var timer: PrepState.timer

    Component.onCompleted: Panels.prepMenu = root

    function show(page) {
        // Timing is chosen on the first page each time; logging otherwise
        mode = "log";
        stack = [];
        draft = null;
        onlyPattern = "";
        PrepState.refresh();
        PrepState.loadProblems();
        menu.show();
        enter(page ?? "", 0);
    }

    function toggle() {
        menu.open ? menu.hide() : show("");
    }

    // Straight to how it went, for a problem picked elsewhere (the card)
    function logProblem(slug) {
        show("");
        const known = PrepState.problems.find(p => p.slug === slug) ?? PrepState.due.find(d => d.problem === slug);
        pick({
            problem: slug,
            title: known?.title ?? (timer?.problem === slug ? timer.title : slug)
        });
    }

    function go(next) {
        stack = stack.concat([page]);
        enter(next, 0);
    }

    function back() {
        if (stack.length === 0) {
            menu.hide();
            return;
        }
        const from = page;
        const to = stack[stack.length - 1];
        stack = stack.slice(0, -1);
        enter(to, Math.max(0, entries.findIndex(e => e.key === from)));
    }

    readonly property var prompts: ({
            mins: "Minutes it took (Enter alone skips)",
            study: "Minutes and what, e.g. 90 Java concurrency",
            contest: "Solved out of 4, then rank, e.g. 2 15230",
            appadd: "Company",
            appnext: "Next step"
        })

    function enter(next, index) {
        menu.prompt = "";
        page = next;
        if (next === "stories")
            PrepState.loadStories();
        menu.replay(index);
        if (prompts[next])
            menu.prompt = prompts[next];
        else if (next === "problem")
            menu.startFilter();
    }

    // A problem picked: its pattern and difficulty if it's new, then the result
    function pick(d) {
        draft = d;
        if (mode === "timer") {
            PrepState.startTimer(d.isNew ? d.title : d.problem);
            menu.hide();
        } else if (d.isNew) {
            go("pattern");
        } else {
            go("result");
        }
    }

    function finish(result, mins) {
        const d = draft;
        const extra = [];
        if (d.isNew) {
            if (d.pattern)
                extra.push("-p", d.pattern);
            if (d.diff)
                extra.push("-d", d.diff);
            if (!/^https?:/.test(d.title))
                extra.push("-t", d.title);
        }
        if (mins !== undefined && mins !== null)
            extra.push("-m", mins);
        PrepState.log(d.problem, result, extra);
        menu.hide();
    }

    // Whether the running timer is this attempt's, so it gives the minutes
    function timed(d) {
        return timer !== null && d !== null && (!timer.problem || timer.problem === d.problem);
    }

    function chooseResult(result) {
        if (timed(draft))
            finish(result);
        else {
            draft = Object.assign({}, draft, {
                result: result
            });
            go("mins");
        }
    }

    function activate(e) {
        switch (page) {
        case "":
            switch (e.key) {
            case "logtimer":
                // A timer on no problem in particular: pick which it was
                if (timer.problem)
                    logProblem(timer.problem);
                else {
                    mode = "log";
                    onlyPattern = "";
                    go("problem");
                }
                return;
            case "log":
                mode = "log";
                onlyPattern = "";
                go("problem");
                return;
            case "timer":
                if (timer) {
                    PrepState.stopTimer();
                    menu.hide();
                } else {
                    mode = "timer";
                    onlyPattern = "";
                    go("problem");
                }
                return;
            case "undo":
                PrepState.run(["undo"], true);
                menu.hide();
                return;
            default:
                go(e.key);
                return;
            }
        case "problem":
            pick(e.draft);
            return;
        case "pattern":
            draft = Object.assign({}, draft, {
                pattern: e.key
            });
            go("diff");
            return;
        case "diff":
            draft = Object.assign({}, draft, {
                diff: e.key
            });
            go("result");
            return;
        case "result":
            chooseResult(e.key);
            return;
        case "patterns":
            mode = "log";
            onlyPattern = e.key;
            go("problem");
            return;
        case "mock":
            mockKind = e.key;
            go("mockresult");
            return;
        case "mockresult":
            PrepState.run(["mock", e.key, "-k", mockKind], true);
            menu.hide();
            return;
        case "apps":
            if (e.key === "add")
                go("appadd");
            else {
                company = e.company;
                go("stage");
            }
            return;
        case "stage":
            PrepState.run(["app", "stage", company, e.key], false);
            back();
            return;
        case "stories":
            Quickshell.execDetached(["uwsm", "app", "--", "ghostty", "-e", "nvim", `+${e.line}`, PrepState.stories.path]);
            menu.hide();
            return;
        }
    }

    function submit(text) {
        text = text.trim();
        switch (page) {
        case "mins":
            {
                const m = parseInt(text);
                finish(draft.result, isNaN(m) ? null : m);
                return;
            }
        case "study":
            {
                const m = text.match(/^(\d+)\s*(.*)$/);
                if (m)
                    PrepState.run(["study", m[1]].concat(m[2] ? [m[2]] : []), true);
                menu.hide();
                return;
            }
        case "contest":
            {
                const m = text.match(/^(\d+)(?:\s+(\d+))?/);
                if (m)
                    PrepState.run(["contest", m[1]].concat(m[2] ? ["-r", m[2]] : []), true);
                menu.hide();
                return;
            }
        case "appadd":
            if (text)
                PrepState.run(["app", "add", text], false);
            back();
            return;
        case "appnext":
            if (text)
                PrepState.run(["app", "next", company, text], false);
            back();
            return;
        }
    }

    function diffLabel(d) {
        return d ? d[0].toUpperCase() + d.slice(1) : "";
    }

    readonly property var marks: ({
            solved: "✓",
            hint: "~",
            fail: "✗"
        })

    function problemRow(p, section) {
        const tries = p.attempts ? ` · tried ${p.attempts}×` : "";
        return {
            key: `${section}:${p.slug}`,
            label: p.title,
            subtitle: `${p.patternName || p.pattern} · ${diffLabel(p.diff)}${tries}`,
            trailing: marks[p.last] ?? "",
            keywords: p.slug,
            section: section,
            draft: {
                problem: p.slug,
                title: p.title
            }
        };
    }

    readonly property var entries: {
        const st = s;
        switch (page) {
        case "":
            {
                const rows = [];
                if (timer)
                    rows.push({
                        key: "logtimer",
                        label: `Log ${timer.title || "the timed attempt"}`,
                        subtitle: `Timing · ${PrepState.clock(PrepState.elapsed)}`,
                        icon: "alarm-timer",
                        accent: true
                    });
                rows.push({
                    key: "log",
                    label: "Log a problem",
                    subtitle: st?.due.length ? `${st.due.length} to re-solve today` : "Solved, hints or failed",
                    icon: "applications-development"
                }, {
                    key: "timer",
                    label: timer ? "Stop the timer" : "Time an attempt",
                    subtitle: timer ? "Without logging it" : `${PrepState.timerMinutes} minutes, as in an interview`,
                    icon: "alarm-timer"
                }, {
                    key: "study",
                    label: "Log study time",
                    subtitle: "Java, concurrency, system design…",
                    icon: "applications-education"
                }, {
                    key: "mock",
                    label: "Log a mock interview",
                    trailing: st ? `${st.totals.mocksPassed}/${st.totals.mocks}` : "",
                    icon: "system-users"
                }, {
                    key: "contest",
                    label: "Log a contest",
                    trailing: st ? `${st.totals.contests}` : "",
                    icon: "applications-games"
                }, {
                    key: "patterns",
                    label: "Patterns",
                    subtitle: "NeetCode 150, pattern by pattern",
                    trailing: st ? `${st.totals.listSolved}/${st.totals.listTotal}` : "",
                    icon: "org.gnome.Todo"
                }, {
                    key: "apps",
                    label: "Applications",
                    subtitle: "Referrals, stages, next steps",
                    trailing: st ? `${st.applications.length}` : "",
                    icon: "planner"
                }, {
                    key: "stories",
                    label: "Behavioural stories",
                    subtitle: "STAR stories for the behavioural round",
                    icon: "accessories-notes"
                });
                if (st?.recent.length)
                    rows.push({
                        key: "undo",
                        label: "Undo the last log",
                        subtitle: `${st.recent[0].title}, ${st.recent[0].result}`,
                        icon: "edit-undo"
                    });
                return rows;
            }
        case "problem":
            {
                const rows = [];
                const all = PrepState.problems;
                const bySlug = {};
                for (const p of all)
                    bySlug[p.slug] = p;
                if (!onlyPattern)
                    for (const d of PrepState.due) {
                        const p = bySlug[d.problem] ?? {
                            slug: d.problem,
                            title: d.title,
                            pattern: d.pattern,
                            patternName: d.pattern,
                            diff: d.diff,
                            last: d.last,
                            attempts: d.attempts
                        };
                        rows.push(problemRow(p, "Re-solve today"));
                    }
                const focus = onlyPattern ? [onlyPattern] : (st?.week?.patterns ?? []);
                for (const id of focus)
                    for (const p of all.filter(p => p.pattern === id && p.last !== "solved"))
                        rows.push(problemRow(p, onlyPattern ? p.patternName : "This week"));
                if (onlyPattern) {
                    for (const p of all.filter(p => p.pattern === onlyPattern && p.last === "solved"))
                        rows.push(problemRow(p, "Solved"));
                } else {
                    for (const p of all)
                        if (!focus.includes(p.pattern) || p.last === "solved")
                            rows.push(problemRow(p, p.patternName || "Your own"));
                }
                const typed = menu.typed.trim();
                if (typed)
                    rows.push({
                        key: "new",
                        label: "New problem",
                        subtitle: typed,
                        keywords: typed,
                        icon: "list-add",
                        section: "Not on the list",
                        draft: {
                            problem: typed,
                            title: typed,
                            isNew: true
                        }
                    });
                return rows;
            }
        case "pattern":
        case "patterns":
            return (st?.patterns ?? []).map(p => ({
                        key: p.id,
                        label: p.name,
                        subtitle: p.open ? `${p.open} to re-solve` : p.tried ? `${p.tried} tried` : "",
                        trailing: `${p.solved}/${p.total}`
                    }));
        case "diff":
            return [
                {
                    key: "easy",
                    label: "Easy"
                },
                {
                    key: "medium",
                    label: "Medium"
                },
                {
                    key: "hard",
                    label: "Hard"
                }
            ];
        case "result":
            {
                const took = timed(draft) ? ` · ${Math.max(1, Math.round(PrepState.elapsed / 60000))} min on the timer` : "";
                return [
                    {
                        key: "solved",
                        label: "Solved clean",
                        subtitle: "No hints" + took,
                        keys: ["S"]
                    },
                    {
                        key: "hint",
                        label: "Solved with hints",
                        subtitle: `Re-solve in 3 days${took}`,
                        keys: ["H"]
                    },
                    {
                        key: "fail",
                        label: "Failed",
                        subtitle: `Re-solve in 3 days${took}`,
                        keys: ["F"]
                    }
                ];
            }
        case "mock":
            return [
                {
                    key: "dsa",
                    label: "DSA",
                    icon: "applications-development"
                },
                {
                    key: "design",
                    label: "System design (HLD)",
                    icon: "network-workgroup"
                },
                {
                    key: "lld",
                    label: "Machine coding (LLD)",
                    icon: "utilities-terminal"
                },
                {
                    key: "behavioural",
                    label: "Behavioural",
                    icon: "system-users"
                }
            ];
        case "mockresult":
            return [
                {
                    key: "pass",
                    label: "Passed"
                },
                {
                    key: "fail",
                    label: "Didn't pass"
                }
            ];
        case "apps":
            return [
                {
                    key: "add",
                    label: "Add a company",
                    icon: "list-add"
                }
            ].concat((st?.applications ?? []).map(a => ({
                        key: `app:${a.company}`,
                        company: a.company,
                        label: a.company,
                        subtitle: a.next ? `Next: ${a.next}` : a.referral ? `Referral: ${a.referral}` : `Since ${a.updated}`,
                        trailing: a.stage,
                        section: ["offer", "signed"].includes(a.stage) ? "Offers" : ["rejected", "withdrawn"].includes(a.stage) ? "Closed" : "Open"
                    })).sort((a, b) => ["Offers", "Open", "Closed"].indexOf(a.section) - ["Offers", "Open", "Closed"].indexOf(b.section)));
        case "stage":
            {
                const a = (st?.applications ?? []).find(a => a.company === company);
                return (st?.stages ?? []).map(stage => ({
                            key: stage,
                            label: ({
                                    oa: "Online assessment",
                                    loop: "Interview loop"
                                })[stage] ?? diffLabel(stage),
                            checked: a?.stage === stage
                        }));
            }
        case "stories":
            return (PrepState.stories?.stories ?? []).map(t => ({
                        key: t.title,
                        label: t.title,
                        subtitle: t.filled ? "" : "Still to write",
                        line: t.line,
                        icon: "accessories-notes"
                    }));
        }
        return [];
    }

    LauncherWindow {
        id: menu

        title: ({
                problem: root.onlyPattern ? (root.s?.patterns.find(p => p.id === root.onlyPattern)?.name ?? "Problems") : root.mode === "timer" ? "Time an attempt" : "Log a problem",
                pattern: "Its pattern",
                diff: "How hard",
                result: root.draft?.title ?? "",
                mins: root.draft?.title ?? "",
                patterns: "Patterns",
                study: "Study time",
                mock: "Mock interview",
                mockresult: "Mock interview",
                contest: "Contest",
                apps: "Applications",
                stage: root.company,
                appadd: "Add a company",
                appnext: root.company,
                stories: "Behavioural stories"
            })[root.page] ?? "Prep"
        placeholder: root.page === "problem" ? "A problem, or a LeetCode URL…" : "Filter…"
        maxRows: 8
        closeOnPick: false
        entryKey: "key"
        promptSecret: false
        canGoBack: root.page !== ""
        entries: root.entries
        onBack: root.back()
        onActivated: entry => root.activate(entry)
        onSubmitted: text => root.submit(text)
        onPromptCancelled: root.back()
        extraKeys: event => {
            if (event.modifiers & Qt.ControlModifier)
                return false;
            if (root.page === "result") {
                const result = ({
                        [Qt.Key_S]: "solved",
                        [Qt.Key_H]: "hint",
                        [Qt.Key_F]: "fail"
                    })[event.key];
                if (result) {
                    root.chooseResult(result);
                    return true;
                }
            }
            if (root.page === "apps" && event.key === Qt.Key_N && menu.currentEntry?.company) {
                root.company = menu.currentEntry.company;
                root.go("appnext");
                return true;
            }
            return false;
        }
    }

    // `qs -c quickbar ipc call prep toggle`, e.g. from Super+D; `prep log`
    // straight to picking a problem; `prep open apps` (or any page)
    IpcHandler {
        target: "prep"

        function toggle(): void {
            root.toggle();
        }

        function log(): void {
            root.mode = "log";
            root.show("problem");
        }

        function open(page: string): void {
            root.show(page);
        }
    }
}
