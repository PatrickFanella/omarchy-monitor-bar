function text(value) {
  return value === undefined || value === null ? "" : String(value).trim()
}

function parseJson(value, fallback) {
  if (typeof value === "object" && value !== null) return value
  if (!text(value)) return fallback
  try { return JSON.parse(String(value)) } catch (error) { return fallback }
}

function uniqueStrings(values) {
  var result = []
  var seen = {}
  if (!Array.isArray(values)) return result
  for (var i = 0; i < values.length; i++) {
    var value = text(values[i])
    if (!value || seen[value]) continue
    seen[value] = true
    result.push(value)
  }
  return result
}

function uniqueId(name, used) {
  var base = text(name).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") || "group"
  var taken = {}
  for (var i = 0; i < (used || []).length; i++)
    taken[typeof used[i] === "object" ? text(used[i].id) : text(used[i])] = true
  if (!taken[base]) return base
  var suffix = 2
  while (taken[base + "-" + suffix]) suffix++
  return base + "-" + suffix
}

function normalizeGroup(group, index, used) {
  group = group && typeof group === "object" ? group : {}
  var name = text(group.name) || "Group " + (index + 1)
  var id = text(group.id)
  if (!id || used[id]) id = uniqueId(name, Object.keys(used))
  used[id] = true
  return {
    id: id,
    name: name,
    icon: text(group.icon) || "\uf07b",
    direction: group.direction === "left" ? "left" : "right",
    widgets: uniqueStrings(group.widgets)
  }
}

function parseWatchedPaths(value) {
  var parsed = parseJson(value, null)
  var result = {}
  if (parsed && !Array.isArray(parsed)) {
    for (var id in parsed) {
      var paths = Array.isArray(parsed[id]) ? parsed[id] : String(parsed[id] || "").split("|")
      paths = uniqueStrings(paths)
      if (paths.length) result[text(id)] = paths
    }
    return result
  }
  var rules = text(value).split(";")
  for (var i = 0; i < rules.length; i++) {
    var split = rules[i].indexOf("=")
    if (split < 1) continue
    var key = text(rules[i].slice(0, split))
    var values = uniqueStrings(rules[i].slice(split + 1).split("|"))
    if (key && values.length) result[key] = values
  }
  return result
}

function parsePolicies(value) {
  var parsed = parseJson(value, {})
  var result = {}
  if (!parsed || Array.isArray(parsed)) return result
  for (var id in parsed) {
    var source = parsed[id]
    if (typeof source === "string") source = { mode: source }
    if (!source || typeof source !== "object") continue
    var seconds = Math.floor(Number(source.revealSeconds || 0))
    result[text(id)] = {
      autoReveal: source.autoReveal !== false && source.mode !== "manual",
      revealSeconds: seconds > 0 ? Math.min(300, seconds) : 0
    }
  }
  return result
}

function normalizeConfig(source) {
  source = source && typeof source === "object" ? source : {}
  var rawGroups = parseJson(source.groups, source.groups)
  if (!Array.isArray(rawGroups)) rawGroups = []
  if (!rawGroups.length) rawGroups = [{ id: "default", name: "Shelfish", icon: "\uf07b", direction: "right", widgets: [] }]
  var groups = []
  var used = {}
  var claimedWidgets = {}
  for (var i = 0; i < rawGroups.length; i++) {
    var group = normalizeGroup(rawGroups[i], i, used)
    group.widgets = group.widgets.filter(function(id) {
      if (claimedWidgets[id]) return false
      claimedWidgets[id] = true
      return true
    })
    groups.push(group)
  }
  var active = text(source.activeGroupId)
  var exists = false
  for (var j = 0; j < groups.length; j++) if (groups[j].id === active) exists = true
  var seconds = Math.floor(Number(source.revealSeconds || 8))
  return {
    groups: groups,
    activeGroupId: exists ? active : (source.activeGroupId === "" ? "" : groups[0].id),
    watchedPaths: parseWatchedPaths(source.watchedPaths),
    policies: parsePolicies(source.policies),
    revealSeconds: Math.max(1, Math.min(300, seconds || 8)),
    widgetConfigs: parseJson(source.widgetConfigs, {}) || {}
  }
}

function cloneConfig(config) {
  return normalizeConfig(JSON.parse(JSON.stringify(config || {})))
}

function groupById(config, id) {
  var groups = config && Array.isArray(config.groups) ? config.groups : []
  for (var i = 0; i < groups.length; i++) if (groups[i].id === id) return groups[i]
  return null
}

function activeGroup(config) {
  return groupById(config, config ? config.activeGroupId : "")
}

function addGroup(config, name) {
  var next = cloneConfig(config)
  var group = { id: uniqueId(name, next.groups), name: text(name) || "Group", icon: "\uf07b", direction: "right", widgets: [] }
  next.groups.push(group)
  next.activeGroupId = group.id
  return next
}

function deleteGroup(config, id) {
  var next = cloneConfig(config)
  if (next.groups.length === 1) return next
  next.groups = next.groups.filter(function(group) { return group.id !== id })
  if (!groupById(next, next.activeGroupId)) next.activeGroupId = next.groups[0].id
  return next
}

function renameGroup(config, id, name) {
  var next = cloneConfig(config)
  var group = groupById(next, id)
  if (group && text(name)) group.name = text(name)
  return next
}

function updateGroup(config, id, values) {
  var next = cloneConfig(config)
  var group = groupById(next, id)
  if (!group) return next
  if (text(values && values.name)) group.name = text(values.name)
  if (text(values && values.icon)) group.icon = text(values.icon)
  if (values && values.direction !== undefined)
    group.direction = values.direction === "left" ? "left" : "right"
  return next
}

function moveGroup(config, id, offset) {
  var next = cloneConfig(config)
  var index = -1
  for (var i = 0; i < next.groups.length; i++) if (next.groups[i].id === id) index = i
  var target = index + (offset < 0 ? -1 : 1)
  if (index < 0 || target < 0 || target >= next.groups.length) return next
  var group = next.groups.splice(index, 1)[0]
  next.groups.splice(target, 0, group)
  return next
}

function setMembership(config, groupId, key, memberId, present) {
  var next = cloneConfig(config)
  var id = text(memberId)
  if (!id) return next
  for (var i = 0; i < next.groups.length; i++) {
    var values = next.groups[i][key]
    var index = values.indexOf(id)
    if (index !== -1 && (present || next.groups[i].id === groupId)) values.splice(index, 1)
  }
  var group = groupById(next, groupId)
  if (group && present) group[key].push(id)
  return next
}

function setWidgetMembership(config, groupId, widgetId, present) {
  return setMembership(config, groupId, "widgets", widgetId, present)
}

function moveWidget(config, groupId, widgetId, offset) {
  var next = cloneConfig(config)
  var group = groupById(next, groupId)
  if (!group) return next
  var index = group.widgets.indexOf(text(widgetId))
  var target = index + (offset < 0 ? -1 : 1)
  if (index < 0 || target < 0 || target >= group.widgets.length) return next
  var widget = group.widgets.splice(index, 1)[0]
  group.widgets.splice(target, 0, widget)
  return next
}

function allWidgetIds(config) {
  var values = []
  var groups = config && config.groups ? config.groups : []
  for (var i = 0; i < groups.length; i++)
    values = values.concat((groups[i].widgets || []).filter(function(id) { return !isSettingsShortcut(id) }))
  return uniqueStrings(values)
}

function isSettingsShortcut(id) {
  return text(id) === "shelfish.settings"
}

function widgetGroupId(config, widgetId) {
  var groups = config && config.groups ? config.groups : []
  for (var i = 0; i < groups.length; i++)
    if ((groups[i].widgets || []).indexOf(widgetId) !== -1) return groups[i].id
  return ""
}

function layoutEntryId(entry) {
  return String(entry && typeof entry === "object" ? entry.id : entry || "")
}

function removeGeneratedEntries(layout, groupPrefix) {
  var sections = ["left", "center", "right"]
  if (!layout) return false
  var changed = false
  for (var s = 0; s < sections.length; s++) {
    var section = sections[s]
    if (!Array.isArray(layout[section])) continue
    var kept = layout[section].filter(function(entry) {
      return layoutEntryId(entry).indexOf(groupPrefix) !== 0
    })
    if (kept.length !== layout[section].length) changed = true
    layout[section] = kept
  }
  return changed
}

function syncGroupEntries(layout, groups, moduleName, groupPrefix, sourceDir, activeGroupId, widgetConfigs) {
  if (!layout || !sourceDir) return false
  var sections = ["left", "center", "right"]
  var hasManager = false
  for (var sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) {
    var existing = layout[sections[sectionIndex]]
    if (!Array.isArray(existing)) continue
    for (var entryIndex = 0; entryIndex < existing.length; entryIndex++)
      if (layoutEntryId(existing[entryIndex]) === moduleName) hasManager = true
  }
  if (!hasManager) return removeGeneratedEntries(layout, groupPrefix)
  var wanted = {}
  for (var g = 0; g < groups.length; g++)
    for (var w = 0; w < groups[g].widgets.length; w++) {
      var memberId = groups[g].widgets[w]
      if (memberId !== moduleName && memberId !== "omarchy.tray" && memberId.indexOf(groupPrefix) !== 0 && !isSettingsShortcut(memberId))
        wanted[memberId] = true
    }

  var memberEntries = {}
  var managerSection = ""
  var managerIndex = -1
  for (var s = 0; s < sections.length; s++) {
    var section = sections[s]
    var source = Array.isArray(layout[section]) ? layout[section] : []
    var kept = []
    for (var i = 0; i < source.length; i++) {
      var id = layoutEntryId(source[i])
      if (id.indexOf(groupPrefix) === 0) continue
      if (wanted[id]) {
        if (!memberEntries[id]) memberEntries[id] = []
        memberEntries[id].push(source[i])
        if (widgetConfigs && typeof widgetConfigs === "object") {
          widgetConfigs[id] = source[i]
        }
        continue
      }
      if (id === moduleName) {
        managerSection = section
        managerIndex = kept.length
      }
      kept.push(source[i])
    }
    layout[section] = kept
  }
  if (!managerSection || managerIndex < 0) return false

  var effectiveActiveId = activeGroupId !== undefined ? activeGroupId : (groups[0] ? groups[0].id : "")

  var additions = []
  for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
    var group = groups[groupIndex]
    var members = []
    if (group.id === effectiveActiveId) {
      for (var memberIndex = 0; memberIndex < group.widgets.length; memberIndex++) {
        var widgetId = group.widgets[memberIndex]
        var entries = memberEntries[widgetId]
        if (entries && entries.length) {
          members = members.concat(entries)
        } else if (widgetConfigs && widgetConfigs[widgetId]) {
          members.push(widgetConfigs[widgetId])
        } else if (isSettingsShortcut(widgetId)) {
          members.push({
            id: groupPrefix + group.id + ".settings",
            source: sourceDir + "/SettingsButton.qml",
            shelfishGroupId: group.id,
            syntheticSettings: true
          })
        } else {
          members.push({ id: widgetId })
        }
      }
    }
    var groupEntry = {
      id: groupPrefix + group.id,
      source: sourceDir + "/GroupButton.qml",
      shelfishGroupId: group.id,
      syntheticSettings: true
    }
    additions = group.direction === "left"
      ? additions.concat(members, [groupEntry])
      : additions.concat([groupEntry], members)
  }
  var target = layout[managerSection]
  target.splice.apply(target, [managerIndex + 1, 0].concat(additions))
  return true
}

function groupedLayout(layout, config, moduleName, sourceDir, registeredWidgets) {
  var result = JSON.parse(JSON.stringify(layout || {left: [], center: [], right: []}))
  config = normalizeConfig(config)
  var present = {}
  ;["left", "center", "right"].forEach(function(section) {
    ;(result[section] || []).forEach(function(entry) { present[layoutEntryId(entry)] = true })
  })
  config.groups.forEach(function(group) {
    group.widgets = group.widgets.filter(function(id) {
      return isSettingsShortcut(id) || ((present[id] || (registeredWidgets && registeredWidgets[id])) && id !== "omarchy.tray"
        && id !== moduleName && id.indexOf(moduleName + ".") !== 0)
    })
  })
  var manager = {id: moduleName, source: sourceDir + "/ManagerWidget.qml", syntheticSettings: true}
  if (!Array.isArray(result.right)) result.right = []
  result.right.push(manager)
  syncGroupEntries(result, config.groups, moduleName, moduleName + ".group.", sourceDir,
    config.activeGroupId, config.widgetConfigs)
  return result
}

function valueAtPath(object, path) {
  var current = object
  var parts = text(path).split(".")
  if (text(path).length > 128 || parts.length > 8) return undefined
  for (var i = 0; i < parts.length; i++) {
    if (!parts[i] || current === undefined || current === null) return undefined
    try { current = current[parts[i]] } catch (error) { return undefined }
  }
  return current
}

function statusScalar(value) {
  if (value === null) return { accepted: true, value: null }
  if (typeof value === "boolean") return { accepted: true, value: value }
  if (typeof value === "number" && isFinite(value)) return { accepted: true, value: value }
  if (typeof value === "string") return { accepted: true, value: value.slice(0, 256) }
  return { accepted: false, value: null }
}

function statusSnapshot(item, widgetId, watchedPaths) {
  if (!item) return ""
  var paths = watchedPaths && watchedPaths[widgetId] ? watchedPaths[widgetId].slice() : []
  if (valueAtPath(item, "shelfishStatus") !== undefined) paths.push("shelfishStatus")
  else if (valueAtPath(item, "omatenderStatus") !== undefined) paths.push("omatenderStatus")
  paths = uniqueStrings(paths).filter(function(path) {
    return path.length <= 128 && path.split(".").length <= 8
  }).slice(0, 16)
  if (!paths.length) return ""
  var values = []
  var snapshot = ""
  for (var i = 0; i < paths.length; i++) {
    var scalar = statusScalar(valueAtPath(item, paths[i]))
    if (!scalar.accepted) continue
    var candidate
    try { candidate = JSON.stringify(values.concat([[paths[i], scalar.value]])) } catch (error) { continue }
    if (candidate.length > 2048) break
    values.push([paths[i], scalar.value])
    snapshot = candidate
  }
  return snapshot
}

function serializeConfig(config) {
  var normalized = normalizeConfig(config)
  function safeJson(val) {
    var s = JSON.stringify(val)
    s = s.replace(/\}{2,}/g, function(m) { return m.split("").join(" ") })
    s = s.replace(/\{{2,}/g, function(m) { return m.split("").join(" ") })
    return s
  }
  return {
    groups: safeJson(normalized.groups),
    activeGroupId: normalized.activeGroupId,
    watchedPaths: safeJson(normalized.watchedPaths),
    policies: safeJson(normalized.policies),
    revealSeconds: normalized.revealSeconds,
    widgetConfigs: safeJson(normalized.widgetConfigs || {})
  }
}

if (typeof module !== "undefined") module.exports = {
  normalizeConfig: normalizeConfig,
  addGroup: addGroup,
  deleteGroup: deleteGroup,
  renameGroup: renameGroup,
  updateGroup: updateGroup,
  moveGroup: moveGroup,
  groupById: groupById,
  activeGroup: activeGroup,
  uniqueId: uniqueId,
  uniqueStrings: uniqueStrings,
  setWidgetMembership: setWidgetMembership,
  moveWidget: moveWidget,
  allWidgetIds: allWidgetIds,
  widgetGroupId: widgetGroupId,
  removeGeneratedEntries: removeGeneratedEntries,
  syncGroupEntries: syncGroupEntries,
  groupedLayout: groupedLayout,
  parseWatchedPaths: parseWatchedPaths,
  parsePolicies: parsePolicies,
  valueAtPath: valueAtPath,
  statusSnapshot: statusSnapshot,
  serializeConfig: serializeConfig
}
