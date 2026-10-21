#!/usr/bin/env node
// Render Material 3's expressive shapes to SVG paths for
// components/MaterialShapes.js.
//
// The shapes are androidx graphics-shapes' (Apache 2.0), from end-4's
// QML JS port, https://github.com/end-4/rounded-polygon-qmljs; this loads
// its libraries in node once, so quickbar needs neither the library nor a
// Canvas to draw them.
//
//     material-shapes.js ROUNDED_POLYGON_QMLJS_DIR Name... > components/MaterialShapes.js
//
// Names are material-shapes.js's getters without "get": Cookie9Sided,
// Clover4Leaf, SoftBurst, ...
const fs = require("fs");
const path = require("path");

const [dir, ...names] = process.argv.slice(2);
if (!dir || names.length === 0) {
    console.error("usage: material-shapes.js ROUNDED_POLYGON_QMLJS_DIR Name...");
    process.exit(2);
}

// QML's `.pragma library` and `.import "file" as Name`, as plain functions
// returning each file's top-level names
const loaded = {};
function load(file) {
    file = path.resolve(file);
    if (loaded[file])
        return loaded[file];
    let src = fs.readFileSync(file, "utf8");
    const imports = [];
    src = src.replace(/^\.pragma.*$/m, "").replace(/^\.import "(.+)" as (\w+)\s*$/gm, (_, f, name) => {
        imports.push([name, path.join(path.dirname(file), f)]);
        return "";
    });
    const exported = [...src.matchAll(/^(?:class|function|var|const|let)\s+(\w+)/gm)].map(m => m[1]);
    const mod = (loaded[file] = {});
    const body = new Function(...imports.map(i => i[0]), `${src}\nreturn {${exported.join(",")}};`);
    Object.assign(mod, body(...imports.map(i => load(i[1]))));
    return mod;
}

const shapes = load(path.join(dir, "material-shapes.js"));
const { Morph } = load(path.join(dir, "shapes/morph.js"));
// The shapes are normalised to 0-1; two decimals in 0-100 is plenty
const n = v => String(Math.round(v * 10000) / 100);

const out = [];
for (const name of names) {
    const get = shapes["get" + name];
    if (!get) {
        console.error(`no shape ${name}`);
        process.exit(1);
    }
    const cubics = new Morph(get(), get()).asCubics(1);
    let d = `M${n(cubics[0].anchor0X)} ${n(cubics[0].anchor0Y)}`;
    for (const c of cubics)
        d += `C${n(c.control0X)} ${n(c.control0Y)} ${n(c.control1X)} ${n(c.control1Y)} ${n(c.anchor1X)} ${n(c.anchor1Y)}`;
    out.push(`    ${name}: "${d}Z"`);
}

console.log(`.pragma library

// Material 3's expressive shapes as SVG paths in a 0-100 viewport, for
// GlyphShape (unit: size / 100). From androidx graphics-shapes (Apache 2.0)
// via end-4's rounded-polygon-qmljs, rendered by tools/material-shapes.js:
//     ${["material-shapes.js", "DIR", ...names].join(" ")}

var shapes = {
${out.join(",\n")}
};`);
