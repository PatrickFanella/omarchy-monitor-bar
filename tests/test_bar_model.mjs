// SPDX-License-Identifier: MIT

import assert from "node:assert/strict"
import fs from "node:fs"
import vm from "node:vm"

const source = fs.readFileSync(new URL("../BarModel.js", import.meta.url), "utf8")
const model = { module: { exports: {} } }
vm.createContext(model)
vm.runInContext(source, model)
const { pickPanelSlot } = model.module.exports

const slot = name => ({ name, visible: true, width: 10, height: 10 })
const focused = slot("focused")
const primary = slot("primary")
const fallback = slot("fallback")
const opened = slot("opened")
const rows = [
  { slot: primary, screenName: "primary", liveFull: true },
  { slot: focused, screenName: "focused", liveFull: true },
  { slot: fallback, screenName: "fallback", liveFull: true },
  { slot: opened, screenName: "minimal", liveFull: false, opened: true }
]

assert.equal(pickPanelSlot(rows, "focused", "primary"), opened)
rows[3].opened = false
assert.equal(pickPanelSlot(rows, "focused", "primary"), focused)
assert.equal(pickPanelSlot(rows, "offline", "primary"), primary)
assert.equal(pickPanelSlot(rows.filter(row => row.screenName !== "primary"), "offline", "primary"), focused)
assert.equal(pickPanelSlot(rows.filter(row => !row.liveFull), "offline", "primary"), null)

console.log("BarModel routing tests passed")
