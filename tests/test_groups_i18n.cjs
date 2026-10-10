const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")

const I18n = require("../groups/I18n.js")

const expectedLocales = ["en", "de", "es", "fr", "it", "pt-BR", "nl", "pl", "hr", "zh-CN"]
const expectedKeys = [
  "settings.title", "settings.shortcut", "group.fallback", "group.newPlaceholder",
  "action.create", "action.save", "action.up", "action.down", "action.delete",
  "action.add", "action.selected", "action.remove", "direction.left", "direction.right",
  "label.groupIcon", "label.availablePlugins", "label.selectedMembers"
]

test("exports the exact supported locales and catalogue keys", () => {
  assert.deepEqual(I18n.SUPPORTED_LOCALES, expectedLocales)
  assert.deepEqual(Object.keys(I18n.ENGLISH), expectedKeys)
  assert.deepEqual(Object.keys(I18n.CATALOGS), expectedLocales)
  for (const locale of expectedLocales)
    assert.deepEqual(Object.keys(I18n.CATALOGS[locale]), expectedKeys)
  for (const locale of expectedLocales.slice(1))
    assert.deepEqual(Object.keys(I18n.RAW_OVERLAYS[locale]), expectedKeys)
})

test("resolves locale aliases and fallbacks", () => {
  const cases = {
    "": "en",
    C: "en",
    "C.UTF-8": "en",
    POSIX: "en",
    "en_US.UTF-8@calendar": "en",
    "de-DE": "de",
    "de_DE.UTF-8": "de",
    "es_MX": "es",
    pt: "pt-BR",
    "pt_PT": "pt-BR",
    "pt-BR.UTF-8": "pt-BR",
    zh: "zh-CN",
    "zh_CN.UTF-8": "zh-CN",
    "zh-Hans": "zh-CN",
    "zh_TW": "en",
    "ja_JP": "en"
  }
  for (const [locale, expected] of Object.entries(cases))
    assert.equal(I18n.resolveLocale(locale), expected, locale)
})

test("falls back per key to English and returns unknown keys", () => {
  const saved = I18n.CATALOGS.de["action.save"]
  delete I18n.CATALOGS.de["action.save"]
  assert.equal(I18n.translate("de", "action.save"), "Save")
  I18n.CATALOGS.de["action.save"] = saved

  assert.equal(I18n.translate("de", "missing.key"), "missing.key")
  assert.equal(I18n.translate("en", "toString"), "toString")
  assert.equal(I18n.translate("en", "constructor"), "constructor")
})

test("returns representative translations", () => {
  const cases = {
    en: "Create",
    de: "Erstellen",
    es: "Crear",
    fr: "Créer",
    it: "Crea",
    "pt-BR": "Criar",
    nl: "Aanmaken",
    pl: "Utwórz",
    hr: "Izradi",
    "zh-CN": "创建"
  }
  for (const [locale, expected] of Object.entries(cases))
    assert.equal(I18n.translate(locale, "action.create"), expected)
})

test("every QML translation key exists and hosted names bypass translation", () => {
  const root = path.resolve(__dirname, "../groups")
  const qmlFiles = ["ManagerWidget.qml", "GroupButton.qml", "ManagePanel.qml", "Service.qml", "SettingsButton.qml"]
  const qml = qmlFiles.map(file => fs.readFileSync(path.join(root, file), "utf8")).join("\n")
  const keys = [...qml.matchAll(/\.tr\("([^"]+)"/g)].map(match => match[1])
  assert.ok(keys.length > 0)
  for (const key of keys) assert.ok(Object.hasOwn(I18n.ENGLISH, key), key)
  assert.match(qml, /text: groupTab\.modelData\.icon \+ " " \+ groupTab\.modelData\.name/)
  assert.match(qml, /text: parent\.modelData\.name/g)
  assert.doesNotMatch(qml, /tr\([^\n]*(modelData\.name|selectedGroup\.name|manifest\.name)/)
})
