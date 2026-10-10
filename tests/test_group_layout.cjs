const assert = require("node:assert/strict")
const Model = require("../groups/Model.js")
const id = "patrickfanella.monitor-bar.groups"
const source = "/tmp/monitor-bar/groups"
const original = {
  left: [{id: "clock", format: "HH:mm"}, {id: "clock", format: "hh:mm"}],
  center: ["mail"], right: ["omarchy.tray"]
}
const before = JSON.stringify(original)
const config = {groups: [{id: "work", widgets: ["clock"], direction: "left"},
  {id: "personal", widgets: ["mail"]}], activeGroupId: "work"}
let layout = Model.groupedLayout(original, config, id, source)
assert.equal(JSON.stringify(original), before)
assert.deepEqual(layout.right.filter(e => e.id === "clock"), original.left)
assert.equal(layout.center.length, 0)
assert.equal(layout.right[0], "omarchy.tray")
assert.equal(layout.right.filter(e => e.id === id).length, 1)
assert.ok(layout.right.findIndex(e => e.id === "clock") < layout.right.findIndex(e => e.id === id + ".group.work"))
layout = Model.groupedLayout(original, {...config, activeGroupId: "personal"}, id, source)
assert.equal(layout.right.filter(e => e.id === "clock").length, 0)
assert.equal(layout.right.filter(e => e === "mail").length, 1)
layout = Model.groupedLayout(original, {...config, activeGroupId: ""}, id, source)
assert.equal(layout.right.filter(e => e.id === "clock" || e === "mail").length, 0)
layout = Model.groupedLayout(original, {groups: [{id: "empty", widgets: []}]}, id, source)
assert.deepEqual(layout.left, original.left)
assert.deepEqual(layout.center, original.center)
assert.equal(JSON.stringify(original), before)
console.log("group layout tests passed")

layout = Model.groupedLayout(original, {groups: [{id: "missing", widgets: ["absent"]}], activeGroupId: "missing"}, id, source)
assert.equal(layout.right.filter(e => e.id === "absent").length, 0)
layout = Model.groupedLayout(original, {groups: [{id: "new", widgets: ["installed"]}], activeGroupId: "new"}, id, source, {installed: {}})
assert.equal(layout.right.filter(e => e.id === "installed").length, 1)
