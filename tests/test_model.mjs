// SPDX-License-Identifier: MIT

import assert from "node:assert/strict"
import fs from "node:fs"
import vm from "node:vm"

const source = fs.readFileSync(new URL("../MonitorBarModel.js", import.meta.url), "utf8")
const model = {}
vm.createContext(model)
vm.runInContext(source, model)
const plain = value => JSON.parse(JSON.stringify(value))

const defaults = model.defaultConfig(["eDP-1", "HDMI-2", "eDP-1", ""])
assert.equal(defaults.primary, "eDP-1")
assert.deepEqual(plain(defaults.outputs), { "eDP-1": { mode: "full" } })
assert.deepEqual(plain(model.outputFor(defaults, "unknown")), { mode: "hidden" })

assert.deepEqual(plain(model.defaultConfig([])), { version: 1, primary: "", outputs: {} })
assert.deepEqual(plain(model.configFromShell({}, [])), { version: 1, primary: "", outputs: {} })
assert.equal(model.configFromShell({}, ["USB-C-7"]).primary, "USB-C-7")

const normalized = model.normalizeConfig({
  primary: "HDMI-A-1",
  outputs: {
    "HDMI-A-1": { mode: "hidden" },
    "DP-3": { mode: "minimal", workspaces: [{ id: 4, label: "four" }, { id: 4, label: 5 }] },
    "extra": { mode: "minimal", glyph: "x", workspaces: [
      { id: -1, label: "bad" }, { id: 12, label: "twelve" },
      { id: 2147483648, label: "too large" }, { id: Number.MAX_SAFE_INTEGER + 1, label: "unsafe" },
      { id: "13", label: "not numeric" }, { id: 14.5, label: "not whole" }
    ] }
  }
})
assert.equal(normalized.outputs["HDMI-A-1"].mode, "full")
assert.deepEqual(Array.from(normalized.outputs["DP-3"].workspaces, w => ({ id: w.id, label: w.label })), [
  { id: 4, label: "four" }
])
assert.deepEqual(Object.keys(normalized.outputs).sort(), ["DP-3", "HDMI-A-1", "extra"])
assert.equal(normalized.outputs["DP-1"], undefined)

const sparse = model.normalizeConfig({ outputs: {} })
assert.deepEqual(plain(sparse), { version: 1, primary: "", outputs: {} })
assert.deepEqual(plain(model.configFromShell({ [model.CONFIG_KEY]: { outputs: {} } }, ["new-monitor"])), {
  version: 1, primary: "", outputs: {}
})
assert.equal(model.configFromShell({ [model.CONFIG_KEY]: null }, ["new-monitor"]).primary, "new-monitor")
assert.equal(model.hasCanonicalConfig({ [model.CONFIG_KEY]: { outputs: {} } }), true)
assert.equal(model.hasCanonicalConfig({ [model.CONFIG_KEY]: null }), false)

const dormant = model.normalizeConfig({
  primary: "main",
  outputs: {
    main: { mode: "hidden", glyph: "saved", workspaces: [{ id: 23, label: "xxiii" }] },
    other: { mode: "minimal", glyph: "also saved", workspaces: [{ id: 23, label: "duplicate while dormant" }] }
  }
})
assert.deepEqual(plain(dormant.outputs.main), {
  mode: "full", glyph: "saved", workspaces: [{ id: 23, label: "xxiii" }]
})
assert.deepEqual(plain(dormant.outputs.other), {
  mode: "minimal", glyph: "also saved", workspaces: [{ id: 23, label: "duplicate while dormant" }]
})
assert.deepEqual(Array.from(normalized.outputs.extra.workspaces, w => ({ id: w.id, label: w.label })), [
  { id: 12, label: "twelve" }
])

const shell = model.withConfig({ bar: { id: "patrickfanella.monitor-bar" }, untouched: true }, normalized)
assert.equal(shell.bar.id, "patrickfanella.monitor-bar")
assert.equal(shell.untouched, true)
assert.deepEqual(JSON.parse(model.serializeConfig(normalized)), plain(shell[model.CONFIG_KEY]))

console.log("MonitorBarModel tests passed")

// A scoped host retains only bar. The new location wins over legacy settings.
const legacy = { primary: "DP-1", outputs: { "DP-1": { mode: "full" } } }
const scoped = { primary: "DP-3", outputs: { "DP-3": { mode: "full" }, "DP-1": { mode: "minimal", glyph: "x" } } }
assert.equal(model.configFromShell({ [model.CONFIG_KEY]: legacy }, []).primary, "DP-1")
assert.equal(model.configFromShell({ bar: { [model.CONFIG_KEY]: scoped }, [model.CONFIG_KEY]: legacy }, []).primary, "DP-3")
assert.equal(model.configFromShell({ bar: { [model.CONFIG_KEY]: scoped } }, []).outputs["DP-1"].mode, "minimal")

// Exercise the real panel Save handler against a host that exposes only bar.
const panel = fs.readFileSync(new URL("../SettingsPanel.qml", import.meta.url), "utf8")
const saveSource = panel.match(/^  function save\([^]*?^  }/m)[0]
const stored = { bar: { id: "omarchy.bar", layout: {right: [{id: "keep.me"}]} }, idle: {lock: 300} }
const context = {
  validationError: "", externalConflict: false, draft: scoped, position: "bottom", transparent: true,
  writingConfig: false, MonitorBarModel: model, clone: plain, draftSerial: 0,
  snapshot: () => "saved", baselineSnapshot: "dirty", externalSnapshot: "",
  currentConfig: () => stored, relevantShellSnapshot: JSON.stringify, refreshMonitors: () => {},
  shell: {mutateShellConfig: mutate => {
    const exposed = {bar: plain(stored.bar)}; mutate(exposed); stored.bar = exposed.bar; return true
  }}
}
vm.runInNewContext(saveSource + ";save()", context)
assert.equal(stored.bar[model.CONFIG_KEY].primary, "DP-3")
assert.equal(stored.bar.position, "bottom")
assert.equal(stored.bar.layout.right[0].id, "keep.me")
assert.equal(stored.idle.lock, 300)
context.baselineSnapshot = "dirty"
context.shell.mutateShellConfig = () => false
vm.runInNewContext(saveSource + ";save()", context)
assert.equal(context.baselineSnapshot, "dirty")
assert.equal(context.writingConfig, false)

const extended = model.normalizeConfig({
  primary: "DP-1",
  workspaceWidget: "evangelion.workspaces",
  outputs: {
    "DP-1": { mode: "full", modules: { right: ["ignored.on.full"] } },
    "DP-3": { mode: "minimal", modules: {
      left: ["magi.clock", { id: "magi.mission", source: "/tmp/evil.qml" }],
      center: ["../escape", "", 7, null, { exec: "rm -rf ~" }],
      right: "not-an-array",
      bogus: ["x.y"]
    } },
    "HDMI-A-1": { mode: "minimal", modules: { center: [] } }
  }
})
assert.equal(extended.workspaceWidget, "evangelion.workspaces")
assert.deepEqual(plain(extended.outputs["DP-3"].modules), { left: ["magi.clock", "magi.mission"] })
assert.deepEqual(plain(extended.outputs["DP-1"].modules), { right: ["ignored.on.full"] }, "modules survive a mode change")
assert.equal(extended.outputs["HDMI-A-1"].modules, undefined)
assert.equal(model.normalizeConfig({ workspaceWidget: "../x" }).workspaceWidget, undefined)
assert.equal(model.normalizeConfig({ workspaceWidget: 5 }).workspaceWidget, undefined)
assert.deepEqual(plain(model.normalizeConfig(JSON.parse(model.serializeConfig(extended)))), plain(extended), "round trip is stable")
console.log("MonitorBarModel minimal modules and workspace widget tests passed")

const labelled = model.normalizeConfig({ primary: "A", outputs: {
  "B": { mode: "minimal", label: "  MAGI-02 // AUX  " },
  "C": { mode: "minimal", label: "   " },
  "D": { mode: "minimal", label: 42 },
  "E": { mode: "minimal", label: "x".repeat(40) }
} })
assert.equal(labelled.outputs.B.label, "MAGI-02 // AUX")
assert.equal(labelled.outputs.C.label, undefined)
assert.equal(labelled.outputs.D.label, undefined)
assert.equal(labelled.outputs.E.label.length, 32)
console.log("MonitorBarModel output label tests passed")
