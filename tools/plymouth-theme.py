#!/usr/bin/env python3
"""The boot splash as a Plymouth theme: Plymouth's own bgrt theme (the
firmware's logo, left where the firmware drew it) with a small Material 3
indeterminate progress bar just below the logo, after a Pixel's boot
animation, in place of its spinner and watermark.

    tools/plymouth-theme.py OUT_DIR

writes the theme (quickbar.plymouth and its images) into OUT_DIR, to be
copied to /usr/share/plymouth/themes/quickbar. It uses Plymouth's two-step
engine, which places the bar (its looping "throbber") on every screen by a
fraction of its size; the bar's frames are centred and padded above, so the
bar sits a fixed distance below the logo, which the firmware draws a fixed
distance below the middle of the built-in panel. The frames are rendered
here, one loop of Material's indeterminate animation: two segments chasing
across a dim track, the track parted around them, with the timings of
Material Components' LinearIndeterminateDisjointAnimatorDelegate.

Needs rsvg-convert, and reads the logo's place from the firmware (ACPI
BGRT) and the panel's size from its first mode. The password dialog's images
are borrowed from Plymouth's spinner theme.
"""

import shutil
import subprocess
import sys
from pathlib import Path

BGRT = Path("/sys/firmware/acpi/bgrt")
SPINNER = Path("/usr/share/plymouth/themes/spinner")
INSTALLED = "/usr/share/plymouth/themes/quickbar"

BAR_WIDTH = 160
BAR_HEIGHT = 3
# From the logo's bottom edge to the bar
BAR_BELOW = 28
# Between the indicator and the track, as Material 3 parts them
GAP = 3
# The logo's silver
COLOR = "#d9d9d9"
TRACK_OPACITY = 0.24


def logo_bottom():
    """How far below the middle of the built-in panel the logo ends"""
    top = int((BGRT / "yoffset").read_text())
    image = (BGRT / "image").read_bytes()
    # A BMP: its height at byte 22, negative when stored top-down
    height = abs(int.from_bytes(image[22:26], "little", signed=True))
    panel = next(Path("/sys/class/drm").glob("card*-eDP-*"))
    panel_height = int((panel / "modes").read_text().split()[0].split("x")[1])
    return top + height - panel_height // 2


# Each frame: the bar at the bottom of a canvas centred on the screen
FRAME_HEIGHT = 2 * (logo_bottom() + BAR_BELOW + BAR_HEIGHT)

# Plymouth's throbber plays all its frames over 2 s, redrawing 30 times a
# second; Material's loop is 1.8 s, stretched to fit
FRAMES = 60
MATERIAL_LOOP_MS = 1800
# (delay, duration) in Material's ms: each segment's head, then its tail
SEGMENTS = [((0, 750), (333, 850)), ((1000, 567), (1267, 533))]


def bezier(x1, y1, x2, y2):
    """CSS cubic-bezier(x1, y1, x2, y2) as a function of 0..1"""

    def at(t, a, b):
        return 3 * a * t * (1 - t) ** 2 + 3 * b * t**2 * (1 - t) + t**3

    def ease(x):
        lo, hi = 0.0, 1.0
        for _ in range(40):
            mid = (lo + hi) / 2
            if at(mid, x1, x2) < x:
                lo = mid
            else:
                hi = mid
        return at((lo + hi) / 2, y1, y2)

    return ease


# Material's standard easing
EASE = bezier(0.4, 0, 0.2, 1)


def progress(ms, delay, duration):
    return EASE(min(1.0, max(0.0, (ms - delay) / duration)))


def indicator(ms):
    """The segments' spans at ms into Material's loop, in pixels"""
    spans = []
    for head, tail in SEGMENTS:
        start = progress(ms, *tail) * BAR_WIDTH
        end = progress(ms, *head) * BAR_WIDTH
        if end - start >= 0.5:
            spans.append((start, end))
    return spans


def track(spans):
    """What's left of the track, parted around the segments"""
    pieces, x = [], 0.0
    for start, end in sorted(spans):
        if start - GAP > x:
            pieces.append((x, start - GAP))
        x = max(x, end + GAP)
    if x < BAR_WIDTH:
        pieces.append((x, BAR_WIDTH))
    return pieces


def pill(start, end, opacity=1.0):
    width = end - start
    radius = min(BAR_HEIGHT, width) / 2
    return (
        f'<rect x="{start:.2f}" y="{FRAME_HEIGHT - BAR_HEIGHT}" width="{width:.2f}" height="{BAR_HEIGHT}" '
        f'rx="{radius:.2f}" fill="{COLOR}" fill-opacity="{opacity}"/>'
    )


def frame(index):
    ms = index / FRAMES * MATERIAL_LOOP_MS
    spans = indicator(ms)
    shapes = [pill(a, b, TRACK_OPACITY) for a, b in track(spans)]
    shapes += [pill(a, b) for a, b in spans]
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{BAR_WIDTH}" '
        f'height="{FRAME_HEIGHT}">{"".join(shapes)}</svg>'
    )


def render(svg, out, *args):
    subprocess.run(["rsvg-convert", *args, "-o", str(out)], input=svg.encode(), check=True)


THEME = f"""[Plymouth Theme]
Name=quickbar
Description=The firmware's logo over an indeterminate progress bar, as on a Pixel
ModuleName=two-step

[two-step]
ImageDir={INSTALLED}
HorizontalAlignment=.5
VerticalAlignment=.5
DialogHorizontalAlignment=.5
DialogVerticalAlignment=.382
DialogClearsFirmwareBackground=true
MessageBelowAnimation=true
Transition=none
TransitionDuration=0.0
BackgroundStartColor=0x000000
BackgroundEndColor=0x000000

[boot-up]
UseEndAnimation=false
UseFirmwareBackground=true

[shutdown]
UseEndAnimation=false
UseFirmwareBackground=true

[reboot]
UseEndAnimation=false
UseFirmwareBackground=true
"""


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: tools/plymouth-theme.py OUT_DIR")
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)

    for i in range(FRAMES):
        render(frame(i), out / f"throbber-{i + 1:04d}.png")
    for name in ["bullet", "capslock", "entry", "keyboard", "keymap-render", "lock"]:
        shutil.copy(SPINNER / f"{name}.png", out)
    (out / "quickbar.plymouth").write_text(THEME)


if __name__ == "__main__":
    main()
