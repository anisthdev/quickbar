#!/usr/bin/env python3
"""Convert Android VectorDrawable XML files to SVG.

Every fill becomes white, keeping its alpha, so the bar can recolour the
icon while dimmed parts (like unlit Wi-Fi bars) stay dimmed.

    vd2svg.py [--bold UNITS] OUT_DIR file.xml [name=file.xml ...]

--bold outlines every filled shape with a stroke UNITS wide (in viewport
units). Android draws these icons for 2.5-3x phone screens; on a 1x
screen their thin strokes land between pixels and look blurry, and a
little extra weight brings them back onto whole pixels.
"""
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

A = "{http://schemas.android.com/apk/res/android}"
bold = 0.0


def path_data(d):
    """Path data SVG can read. Animated vectors exported from Lottie end
    shapes with a bare "c" that has no coordinates; Android skips it, but an
    SVG renderer stops parsing there and loses every later subpath."""
    return re.sub(r"[cC](?=\s*(?:[Mm]|$))", "", d)


def alpha_of(color):
    """Alpha of an Android colour literal; theme references count as opaque."""
    if not color or not color.startswith("#"):
        return 1.0
    hexs = color[1:]
    if len(hexs) == 4:  # #ARGB
        return int(hexs[0] * 2, 16) / 255
    if len(hexs) == 8:  # #AARRGGBB
        return int(hexs[:2], 16) / 255
    return 1.0


clip_ids = iter(range(1, 1_000_000))


def convert(node):
    out = []
    children = list(node)
    for i, child in enumerate(children):
        tag = child.tag
        if tag == "group":
            g = lambda k, d="0": child.get(A + k, d)
            px, py = float(g("pivotX")), float(g("pivotY"))
            t = (f"translate({float(g('translateX')) + px} {float(g('translateY')) + py}) "
                 f"rotate({g('rotation')}) scale({g('scaleX', '1')} {g('scaleY', '1')}) "
                 f"translate({-px} {-py})")
            if t == "translate(0.0 0.0) rotate(0) scale(1 1) translate(-0.0 -0.0)":
                out.append(convert(child))
            else:
                out.append(f'<g transform="{t}">{convert(child)}</g>')
        elif tag == "path":
            d = path_data(child.get(A + "pathData"))
            fill = child.get(A + "fillColor")
            stroke = child.get(A + "strokeColor")
            attrs = [f'd="{d}"']
            if fill:
                a = alpha_of(fill) * float(child.get(A + "fillAlpha", "1"))
                attrs.append('fill="#fff"')
                if bold:
                    attrs.append(f'stroke="#fff" stroke-width="{bold}" stroke-linejoin="round"')
                # opacity rather than fill-opacity, so a bold stroke and the
                # fill under it don't add up to a brighter outline
                if a < 1:
                    attrs.append(f'opacity="{a:.3g}"')
            else:
                attrs.append('fill="none"')
            if stroke:
                a = alpha_of(stroke) * float(child.get(A + "strokeAlpha", "1"))
                attrs.append(f'stroke="#fff" stroke-width="{child.get(A + "strokeWidth", "1")}"')
                if a < 1:
                    attrs.append(f'stroke-opacity="{a:.3g}"')
                cap = child.get(A + "strokeLineCap")
                if cap:
                    attrs.append(f'stroke-linecap="{cap}"')
            if child.get(A + "fillType") == "evenOdd":
                attrs.append('fill-rule="evenodd"')
            out.append(f"<path {' '.join(attrs)}/>")
        elif tag == "clip-path":
            # A clip-path clips every later sibling in its group
            cid = f"c{next(clip_ids)}"
            rest = ET.Element("group")
            rest.extend(children[i + 1:])
            # In <defs>, or Qt's SVG renderer paints the clip shape itself
            out.append(f'<defs><clipPath id="{cid}"><path d="{path_data(child.get(A + "pathData"))}"/></clipPath></defs>'
                       f'<g clip-path="url(#{cid})">{convert(rest)}</g>')
            break
    return "".join(out)


def main():
    global bold
    args = sys.argv[1:]
    if args[0] == "--bold":
        bold = float(args[1])
        args = args[2:]
    out_dir = Path(args[0])
    for arg in args[1:]:
        name, _, src = arg.rpartition("=")
        src = Path(src)
        name = name or src.stem
        root = ET.parse(src).getroot()
        vw, vh = root.get(A + "viewportWidth"), root.get(A + "viewportHeight")
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{vw}" height="{vh}" '
               f'viewBox="0 0 {vw} {vh}">{convert(root)}</svg>\n')
        (out_dir / f"{name}.svg").write_text(svg)


if __name__ == "__main__":
    main()
