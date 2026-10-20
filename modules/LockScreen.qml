import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick
import ".."

// The lock screen, in hyprlock's place: the session lock, with a lock
// surface (LockSurface) on every screen. It unlocks with the password
// (typed anywhere; PAM's own `login` stack checks it) or a finger on the
// reader (pam_fprintd, through pam/fprint), both waiting at once, as on
// hyprlock.
//
// `preview` shows the same screen in an ordinary window without locking
// anything, to see it; a right password or finger closes it too.
//
// If quickbar dies while locked, Hyprland keeps the screen locked; from a
// TTY, `hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hyprlock")'` puts
// hyprlock in its place (allow_session_lock_restore).
Scope {
    id: root

    property bool locked: false
    property bool previewing: false
    readonly property bool active: locked || previewing

    // The screens' show and hide, 0 to 1
    property real reveal: 0
    property string wallpaper: ""
    // The passwd entry's full name, or the login name
    property string userName: {
        const user = Quickshell.env("USER") ?? "";
        return user.charAt(0).toUpperCase() + user.slice(1);
    }

    // What's typed, kept here; `dots` has one row per character, for the
    // field's dots to come and go one by one
    property string password: ""
    readonly property ListModel dots: ListModel {}
    property bool checking: false
    // Wrong password (or finger): the field shakes, the message says so
    property string message: ""
    property int failures: 0

    // "ready", "failed" (just now), "off" (too many tries or no reader)
    property string finger: "ready"

    signal shake

    function lock() {
        if (locked)
            return;
        previewing = false;
        reset();
        wallpaperQuery.running = true;
        locked = true;
        start();
    }

    function preview() {
        if (active)
            return;
        reset();
        wallpaperQuery.running = true;
        previewing = true;
        start();
    }

    function reset() {
        clear();
        message = "";
        checking = false;
        finger = "ready";
        fingerErrors = 0;
    }

    function start() {
        hideAnim.stop();
        showAnim.restart();
        fprint.begin();
    }

    // A right password or finger: the screen folds away, then lets go
    function unlock() {
        if (pam.active)
            pam.abort();
        if (fprint.active)
            fprint.abort();
        retry.stop();
        checking = false;
        showAnim.stop();
        hideAnim.restart();
    }

    function finish() {
        clear();
        locked = false;
        previewing = false;
    }

    function type(text) {
        if (checking)
            return;
        message = "";
        password += text;
        for (let i = 0; i < text.length; i++)
            dots.append({});
    }

    function backspace() {
        if (checking || password === "")
            return;
        password = password.slice(0, -1);
        dots.remove(dots.count - 1);
    }

    function clear() {
        password = "";
        dots.clear();
    }

    function submit() {
        if (checking || password === "")
            return;
        checking = true;
        message = "";
        if (!pam.start()) {
            checking = false;
            message = "Couldn't check the password";
        }
    }

    // The password: `login`'s stack asks for it once, and says yes or no
    PamContext {
        id: pam

        config: "login"
        onResponseRequiredChanged: {
            if (responseRequired)
                respond(root.password);
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.unlock();
                return;
            }
            root.checking = false;
            root.failures++;
            root.clear();
            root.message = result === PamResult.MaxTries ? "Too many tries, wait a while" : "Wrong password";
            root.shake();
        }
        onError: error => {
            root.checking = false;
            root.message = "Couldn't check the password";
        }
    }

    // A finger: pam_fprintd takes three swipes (each miss a message), and
    // gives up after pam/fprint's timeout, when it starts again. Quick
    // failures in a row mean no reader: the password only, then
    property int fingerErrors: 0

    PamContext {
        id: fprint

        property real startedAt: 0

        function begin() {
            if (root.finger === "off" || active || !root.active)
                return;
            startedAt = Date.now();
            if (!start())
                root.finger = "off";
        }

        function giveUp() {
            if (Date.now() - startedAt < 3000 && ++root.fingerErrors >= 3)
                root.finger = "off";
            else
                retry.restart();
        }

        configDirectory: Quickshell.shellDir + "/pam"
        config: "fprint"
        onPamMessage: {
            if (!messageIsError)
                return;
            root.finger = "failed";
            root.message = "Not recognised";
            root.shake();
            settle.restart();
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.unlock();
            } else if (result === PamResult.Failed || result === PamResult.MaxTries) {
                root.finger = "off";
                root.message = "Too many tries, use your password";
                root.shake();
            } else {
                giveUp();
            }
        }
        onError: error => giveUp()
    }

    Timer {
        id: retry

        interval: 800
        onTriggered: fprint.begin()
    }

    // A miss shows for a moment
    Timer {
        id: settle

        interval: 1500
        onTriggered: {
            if (root.finger === "failed")
                root.finger = "ready";
        }
    }

    NumberAnimation {
        id: showAnim

        target: root
        property: "reveal"
        to: 1
        duration: 450
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.emphasizedDecel
    }

    NumberAnimation {
        id: hideAnim

        target: root
        property: "reveal"
        to: 0
        duration: 260
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.emphasizedAccel
        onFinished: root.finish()
    }

    // `awww query`: "…: eDP-1: …, currently displaying: image: <path>"
    Process {
        id: wallpaperQuery

        command: ["awww", "query"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/image: (.+)$/m);
                if (m)
                    root.wallpaper = m[1].trim();
            }
        }
    }

    // `getent passwd $USER`: "asif:x:1000:1000:Full Name,…:/home/…"
    Process {
        id: passwd

        command: ["getent", "passwd", Quickshell.env("USER") ?? ""]
        stdout: StdioCollector {
            onStreamFinished: {
                const name = (text.split(":")[4] ?? "").split(",")[0].trim();
                if (name !== "")
                    root.userName = name;
            }
        }
    }

    // Ready before the first lock, so it shows at once
    Component.onCompleted: {
        wallpaperQuery.running = true;
        passwd.running = true;
    }

    WlSessionLock {
        locked: root.locked

        WlSessionLockSurface {
            color: "black"

            LockSurface {
                anchors.fill: parent
                lock: root
            }
        }
    }

    Variants {
        model: root.previewing ? [Quickshell.screens[0]] : []

        PanelWindow {
            required property var modelData

            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "quickbar-lock-preview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            LockSurface {
                anchors.fill: parent
                lock: root
            }
        }
    }

    // `qs -p <dir> ipc call lock lock`, e.g. from hypridle and the power
    // menu; `… lock preview` shows it without locking, `… lock close`
    // closes the preview
    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }

        function preview(): void {
            root.preview();
        }

        function close(): void {
            if (root.previewing)
                root.unlock();
        }

        function isLocked(): bool {
            return root.locked;
        }
    }
}
