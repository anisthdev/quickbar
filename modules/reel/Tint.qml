import QtQuick
import Quickshell
import "../.."

// A title's own colours, from its backdrop, as streaming apps take them: a
// `glow` to wash its page or card with (quiet: mostly dark, a hint of the
// picture), an `accent` for Play and the focus ring (made to stand out on
// the glow), and `onAccent` for what's written on the accent. The theme's
// colours until the picture's read, or for one without colour; changes
// fade, so the hero drifts from one title's colours to the next.
QtObject {
    id: root

    // A picture's path (not a URL)
    property string source
    // Fitted to a dark page (the hero's card is always dark), or the theme's
    property bool dark: !Theme.light

    readonly property color fallbackGlow: dark && Theme.light ? "#1c1f22" : Qt.rgba(Theme.surface_container_high.r, Theme.surface_container_high.g, Theme.surface_container_high.b, 1)
    readonly property color fallbackAccent: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 1)
    readonly property var picked: pick(quantizer.colors, dark)

    property color glow: picked?.glow ?? fallbackGlow
    property color accent: picked?.accent ?? fallbackAccent
    readonly property color onAccent: luminance(accent) > 0.4 ? "#000000" : "#ffffff"

    Behavior on glow {
        ColorAnimation {
            duration: 500
        }
    }
    Behavior on accent {
        ColorAnimation {
            duration: 500
        }
    }

    property ColorQuantizer quantizer: ColorQuantizer {
        source: root.source ? `file://${root.source}` : ""
        depth: 4
        rescaleSize: 64
    }

    function luminance(c) {
        const lin = x => x <= 0.03928 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4);
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
    }

    // The glow from a colour with some colour in it and not too light; the
    // accent from the most vivid, lifted (or, on a light theme, deepened)
    // until it reads
    function pick(colors, dark) {
        if (!colors || colors.length === 0)
            return null;
        let glow = null, glowScore = -1, accent = null, accentScore = -1;
        for (const c of colors) {
            const s = c.hslSaturation, l = c.hslLightness;
            const a = s * (1 - Math.abs(l - 0.55) * 1.4);
            if (a > accentScore) {
                accentScore = a;
                accent = c;
            }
            const g = s * 0.6 + (1 - Math.abs(l - 0.3)) * 0.4;
            if (g > glowScore) {
                glowScore = g;
                glow = c;
            }
        }
        const hue = c => Math.max(0, c.hslHue);
        const out = {
            glow: Qt.hsla(hue(glow), Math.min(glow.hslSaturation, 0.45), dark ? 0.15 : 0.88, 1),
            accent: null
        };
        // A picture without colour keeps the theme's accent
        if (accent.hslSaturation >= 0.15)
            out.accent = Qt.hsla(hue(accent), Math.max(accent.hslSaturation, 0.45), dark ? Math.max(accent.hslLightness, 0.7) : Math.min(accent.hslLightness, 0.38), 1);
        return out;
    }
}
