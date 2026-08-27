// SPDX-License-Identifier: MIT

var CONFIG_KEY = "patrickfanella.monitor-bar"

var DEFAULT_CONFIG = {
  version: 1,
  primary: "",
  outputs: {}
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
}

function clone(value) {
  return JSON.parse(JSON.stringify(value))
}

function connectedNames(value) {
  var source = Array.isArray(value) ? value : []
  var seen = {}
  var names = []
  for (var i = 0; i < source.length; i++) {
    var name = String(source[i] || "")
    if (!name || seen[name]) continue
    seen[name] = true
    names.push(name)
  }
  return names
}

function defaultConfig(connectedMonitorNames) {
  var config = clone(DEFAULT_CONFIG)
  var names = connectedNames(connectedMonitorNames)
  if (names.length > 0) {
    config.primary = names[0]
    config.outputs[names[0]] = { mode: "full" }
  }
  return config
}

function validMode(value, fallback) {
  return value === "full" || value === "minimal" || value === "hidden" ? value : fallback
}

function outputNames(sourceOutputs, primary) {
  var seen = {}
  var names = []
  function add(name) {
    name = String(name || "")
    if (!name || seen[name]) return
    seen[name] = true
    names.push(name)
  }
  add(primary)
  Object.keys(sourceOutputs).sort().forEach(add)
  return names
}

function normalizeWorkspaces(value, fallback, usedIds) {
  var source = Array.isArray(value) ? value : fallback
  var result = []
  for (var i = 0; i < source.length; i++) {
    var item = isObject(source[i]) ? source[i] : {}
    var id = item.id
    if (!Number.isSafeInteger(id) || id <= 0 || id > 2147483647 || usedIds[id]) continue
    var label = typeof item.label === "string"
      ? item.label
      : String(id)
    usedIds[id] = true
    result.push({ id: id, label: label })
  }
  return result
}

function normalizeConfig(value) {
  var configPresent = isObject(value)
  var source = configPresent ? value : DEFAULT_CONFIG
  var sourceOutputs = isObject(source.outputs) ? source.outputs : {}
  var requestedPrimary = typeof source.primary === "string" ? source.primary : ""
  var names = outputNames(sourceOutputs, requestedPrimary)
  var outputs = {}
  var usedIds = {}

  for (var i = 0; i < names.length; i++) {
    var name = names[i]
    var rawPresent = isObject(sourceOutputs[name])
    var fallback = { mode: "hidden" }
    var raw = rawPresent ? sourceOutputs[name] : fallback
    var mode = name === requestedPrimary ? "full" : validMode(raw.mode, fallback.mode)
    var normalized = { mode: mode }
    if (typeof raw.glyph === "string" || typeof fallback.glyph === "string") {
      normalized.glyph = typeof raw.glyph === "string"
        ? raw.glyph
        : (typeof fallback.glyph === "string" ? fallback.glyph : "")
    }
    if (Array.isArray(raw.workspaces) || Array.isArray(fallback.workspaces)) {
      normalized.workspaces = normalizeWorkspaces(
        raw.workspaces,
        fallback.workspaces,
        mode === "minimal" ? usedIds : {}
      )
    }
    outputs[name] = normalized
  }

  return { version: 1, primary: requestedPrimary, outputs: outputs }
}

function hasCanonicalConfig(shellConfig) {
  return isObject(shellConfig)
    && Object.prototype.hasOwnProperty.call(shellConfig, CONFIG_KEY)
    && isObject(shellConfig[CONFIG_KEY])
}

function configFromShell(shellConfig, connectedMonitorNames) {
  if (!hasCanonicalConfig(shellConfig))
    return defaultConfig(connectedMonitorNames)
  return normalizeConfig(shellConfig[CONFIG_KEY])
}

function outputFor(config, screenName) {
  var normalized = normalizeConfig(config)
  var name = String(screenName || "")
  return isObject(normalized.outputs[name]) ? clone(normalized.outputs[name]) : { mode: "hidden" }
}

function isPrimary(config, screenName) {
  return normalizeConfig(config).primary === String(screenName || "")
}

function withConfig(shellConfig, config) {
  var result = isObject(shellConfig) ? clone(shellConfig) : {}
  result[CONFIG_KEY] = normalizeConfig(config)
  return result
}

function serializeConfig(config) {
  return JSON.stringify(normalizeConfig(config), null, 2)
}
