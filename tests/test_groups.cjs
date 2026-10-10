const assert = require("node:assert/strict")
const Model = require("../groups/Model.js")

const base = Model.normalizeConfig({
  groups: '[{"id":"work","name":"Work","icon":"W","direction":"left","widgets":["clock","clock"]},{"id":"other","name":"Other","widgets":["clock","mail"]}]',
  activeGroupId: "missing",
  watchedPaths: "clock=state|nested.value;mail=count",
  policies: '{"clock":{"autoReveal":false,"revealSeconds":12}}'
})

assert.equal(base.activeGroupId, "work")
assert.deepEqual(base.groups[0].widgets, ["clock"])
assert.deepEqual(base.groups[1].widgets, ["mail"])
assert.deepEqual(base.watchedPaths.clock, ["state", "nested.value"])
assert.deepEqual(base.policies.clock, { autoReveal: false, revealSeconds: 12 })
assert.equal(base.groups[0].icon, "W")
assert.equal(base.groups[0].direction, "left")

let config = Model.addGroup(base, "Work")
assert.equal(config.groups[2].id, "work-2")
config = Model.renameGroup(config, "work-2", "Personal")
assert.equal(Model.groupById(config, "work-2").name, "Personal")
config = Model.updateGroup(config, "work-2", { icon: "P", direction: "left" })
assert.equal(Model.groupById(config, "work-2").icon, "P")
assert.equal(Model.groupById(config, "work-2").direction, "left")
config = Model.moveGroup(config, "work-2", -1)
assert.equal(config.groups[1].id, "work-2")
config = Model.deleteGroup(config, "work")
assert.equal(config.activeGroupId, "work-2")

config = Model.setWidgetMembership(config, "work-2", "weather", true)
assert.equal(Model.widgetGroupId(config, "weather"), "work-2")
config = Model.setWidgetMembership(config, "work-2", "clock", true)
config = Model.setWidgetMembership(config, "work-2", "mail", true)
assert.deepEqual(Model.groupById(config, "other").widgets, [])
config = Model.moveWidget(config, "work-2", "mail", -1)
assert.deepEqual(Model.groupById(config, "work-2").widgets, ["weather", "mail", "clock"])

const item = { shelfishStatus: "busy", nested: { value: 3 } }
const snapshot = Model.statusSnapshot(item, "clock", { clock: ["nested.value"] })
assert.match(snapshot, /nested.value/)
assert.match(snapshot, /shelfishStatus/)
assert.equal(Model.valueAtPath(item, "nested.value"), 3)
assert.equal(Model.statusSnapshot({ state: { nested: true } }, "clock", { clock: ["state"] }), "")
assert.equal(Model.statusSnapshot({ state: ["busy"] }, "clock", { clock: ["state"] }), "")
const longSnapshot = Model.statusSnapshot({ state: "x".repeat(1000) }, "clock", { clock: ["state"] })
assert.equal(JSON.parse(longSnapshot)[0][1].length, 256)
const aggregateItem = {}
const aggregatePaths = []
for (let i = 0; i < 16; i++) {
  aggregateItem["status" + i] = "x".repeat(256)
  aggregatePaths.push("status" + i)
}
assert.ok(Model.statusSnapshot(aggregateItem, "clock", { clock: aggregatePaths }).length <= 2048)
assert.equal(Model.valueAtPath({ a: { b: { c: { d: { e: { f: { g: { h: { i: 1 } } } } } } } } }, "a.b.c.d.e.f.g.h.i"), undefined)

const serialized = Model.serializeConfig(config)
assert.equal(Model.normalizeConfig(serialized).groups[0].name, "Personal")
assert.deepEqual(Object.keys(Model.normalizeConfig(serialized).groups[0]).sort(), ["direction", "icon", "id", "name", "widgets"])

const firstClock = { id: "clock", settings: { format: "short" } }
const secondClock = { id: "clock", settings: { format: "long" } }
const layout = {
  left: [firstClock, { id: "io.github.patrickfanella.shelfish.group.old" }],
  center: [secondClock],
  right: [{ id: "io.github.patrickfanella.shelfish" }, { id: "mail", color: "blue" }]
}
assert.equal(Model.syncGroupEntries(layout, [{
  id: "work", direction: "right", widgets: ["clock"]
}], "io.github.patrickfanella.shelfish", "io.github.patrickfanella.shelfish.group.", "/plugin"), true)
assert.deepEqual(layout.left, [])
assert.deepEqual(layout.center, [])
assert.equal(layout.right[1].id, "io.github.patrickfanella.shelfish.group.work")
assert.strictEqual(layout.right[2], firstClock)
assert.strictEqual(layout.right[3], secondClock)
assert.deepEqual(layout.right[2].settings, { format: "short" })
assert.deepEqual(layout.right[3].settings, { format: "long" })
assert.equal(Model.removeGeneratedEntries(layout, "io.github.patrickfanella.shelfish.group."), true)
assert.deepEqual(layout.right.map(entry => entry.id), ["io.github.patrickfanella.shelfish", "clock", "clock", "mail"])

const shortcutLayout = { left: [{ id: "shelfish" }], center: [], right: [] }
assert.equal(Model.syncGroupEntries(shortcutLayout, [{ id: "one", name: "One", icon: "*", direction: "right", widgets: ["shelfish.settings"] }], "shelfish", "shelfish.group.", "/tmp/shelfish"), true)
assert.equal(shortcutLayout.left[1].id, "shelfish.group.one")
assert.equal(shortcutLayout.left[2].id, "shelfish.group.one.settings")
assert.deepEqual(Model.allWidgetIds({ groups: [{ widgets: ["shelfish.settings", "clock"] }] }), ["clock"])

// Multi-group activeGroupId filtering test
const multiLayout = {
  center: [
    { id: "clock" },
    { id: "shelfish" },
    { id: "widgetA", customOpt: 123 },
    { id: "widgetB", customOpt: 456 }
  ]
}
const groupsDef = [
  { id: "grp1", name: "Group 1", widgets: ["widgetA"] },
  { id: "grp2", name: "Group 2", widgets: ["widgetB"] }
]
const widgetConfigs = {}

// Activate grp1
assert.equal(Model.syncGroupEntries(multiLayout, groupsDef, "shelfish", "shelfish.group.", "/tmp/shelfish", "grp1", widgetConfigs), true)
// Center should have: clock, shelfish, group.grp1, widgetA (from grp1), group.grp2 (WITHOUT widgetB!)
const centerIds1 = multiLayout.center.map(e => e.id)
assert.deepEqual(centerIds1, ["clock", "shelfish", "shelfish.group.grp1", "widgetA", "shelfish.group.grp2"])
assert.equal(multiLayout.center[3].customOpt, 123)
assert.equal(widgetConfigs["widgetB"].customOpt, 456)

// Now activate grp2
assert.equal(Model.syncGroupEntries(multiLayout, groupsDef, "shelfish", "shelfish.group.", "/tmp/shelfish", "grp2", widgetConfigs), true)
const centerIds2 = multiLayout.center.map(e => e.id)
assert.deepEqual(centerIds2, ["clock", "shelfish", "shelfish.group.grp1", "shelfish.group.grp2", "widgetB"])
assert.equal(multiLayout.center[4].customOpt, 456)
assert.equal(widgetConfigs["widgetA"].customOpt, 123)

// Now collapse all groups (activeGroupId = "")
assert.equal(Model.syncGroupEntries(multiLayout, groupsDef, "shelfish", "shelfish.group.", "/tmp/shelfish", "", widgetConfigs), true)
const centerIds3 = multiLayout.center.map(e => e.id)
assert.deepEqual(centerIds3, ["clock", "shelfish", "shelfish.group.grp1", "shelfish.group.grp2"])

// Verify serializeConfig escapes consecutive double curly braces to protect Go templates (e.g. chezmoi)
const safeSerialized = Model.serializeConfig({
  groups: [{ id: "g1", name: "G1", widgets: ["w1"] }],
  widgetConfigs: { w1: { id: "w1", nested: { a: 1 } } }
})
assert.equal(safeSerialized.widgetConfigs.includes("}}"), false)
assert.equal(safeSerialized.widgetConfigs.includes("{{"), false)
assert.equal(safeSerialized.widgetConfigs.includes("} }"), true)

console.log("model tests passed")
