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
