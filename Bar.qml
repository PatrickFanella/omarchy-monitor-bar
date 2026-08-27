import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// A deliberately small bar host.  The shipped widgets stay in Omarchy and
// arrive through BarWidgetRegistry; this plugin only chooses a layout for the
// monitor that owns each PanelWindow.
Item {
  id: root

  // The shell injects these immediately after an async plugin Loader finishes.
  // Defaults keep the first construction quiet and hold the surfaces until the
  // shared registry is available.
  property string omarchyPath: ""
  property var barWidgetRegistry: null
  property var barConfig: ({})
  property var shell: null
  property var manifest: null

  property string home: Quickshell.env("HOME")
  property string position: "top"
  property bool requestedTransparent: false
  property bool transparent: false
  property bool foregroundAnimationEnabled: true
  property bool barHidden: false
  property bool centerSectionRevealHeld: false
  property bool centerHoverRevealSuppressed: false
  property var layoutConfig: ({ left: [], center: [], right: [] })
  property var liveWidgets: []
  property var clickTargets: []
  property var moduleSlots: []
  property var activePopout: null
  property bool configured: false
  property int registrySerial: 0

  property string fontFamily: Style.font.family
  property color themeForeground: Color.bar.text
  property color themeContrastForeground: Color.background
  property color transparentForeground: Color.bar.text
  property color foreground: themeForeground
  property color barForeground: transparent ? transparentForeground : themeForeground
  property color background: Color.bar.background
  property color urgent: Color.bar.active

  // Widgets declare `bar` as a QtObject. Keep that contract while exposing
  // only the small host surface they use; the visual root remains an Item.
  property QtObject barAdapter: QtObject {
    readonly property var shell: root.shell
    readonly property string position: root.position
    readonly property bool vertical: root.vertical
    readonly property int barSize: root.barSize
    readonly property string fontFamily: root.fontFamily
    readonly property color foreground: root.foreground
    readonly property color barForeground: root.barForeground
    readonly property color background: root.background
    readonly property color urgent: root.urgent
    readonly property bool barHidden: root.barHidden
    readonly property bool foregroundAnimationEnabled: root.foregroundAnimationEnabled
    readonly property var clickTargets: root.clickTargets
    readonly property var moduleSlots: root.moduleSlots
    property bool centerSectionRevealHeld: root.centerSectionRevealHeld
    property bool centerHoverRevealSuppressed: root.centerHoverRevealSuppressed
    property var activePopout: root.activePopout

    onCenterSectionRevealHeldChanged: root.centerSectionRevealHeld = centerSectionRevealHeld
    onCenterHoverRevealSuppressedChanged: root.centerHoverRevealSuppressed = centerHoverRevealSuppressed

    function run(command) { root.run(command) }
    function shellQuote(value) { return root.shellQuote(value) }
    function moduleWidgets(id) { return root.moduleWidgets(id) }
    function showTooltip(target, text) { root.showTooltip(target, text) }
    function hideTooltip(target) { root.hideTooltip(target) }
    function requestPopout(owner) { root.requestPopout(owner); activePopout = owner }
    function releasePopout(owner) { root.releasePopout(owner); activePopout = root.activePopout }
    function switchPanelFrom(owner, direction) { return root.switchPanelFrom(owner, direction) }
  }

  Connections {
    target: root.barWidgetRegistry
    function onChanged() { root.registrySerial++ }
  }

  readonly property bool vertical: position === "left" || position === "right"
  readonly property int barSize: vertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal
  readonly property string stateHome: home + "/.local/state"
  readonly property string monitorGlyphWidgetSource: home + "/.config/omarchy/plugins/onnwee.monitor-bar/MonitorGlyph.qml"

  function normalizePosition(value) {
    var candidate = String(value || "")
    return /^(top|bottom|left|right)$/.test(candidate) ? candidate : "top"
  }

  function entryId(entry) {
    if (typeof entry === "string") return entry
    return entry && entry.id ? String(entry.id) : ""
  }

  function entrySettings(entry) {
    var result = {}
    if (!entry || typeof entry !== "object") return result
    for (var key in entry) if (key !== "id") result[key] = entry[key]
    return result
  }

  function customModuleSource(entry) {
    if (!entry || typeof entry !== "object" || !entry.source) return ""
    var source = String(entry.source)
    if (source.indexOf("~/") === 0) source = home + source.substring(1)
    return Util.fileUrl(source)
  }

  readonly property string workspaceWidgetSource: home + "/.config/omarchy/plugins/onnwee.monitor-bar/Workspaces.qml"

  function copy(value) {
    try { return JSON.parse(JSON.stringify(value)) } catch (e) { return value }
  }

  function existingEntry(id) {
    var layout = barConfig && barConfig.layout ? barConfig.layout : {}
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var entries = Array.isArray(layout[sections[s]]) ? layout[sections[s]] : []
      for (var i = 0; i < entries.length; i++) {
        if (entryId(entries[i]) === id) return copy(entries[i])
      }
    }
    return { id: id }
  }

  function monitorWorkspaceEntry(entry, displayLabels) {
    var result = entry && typeof entry === "object" ? copy(entry) : { id: "omarchy.workspaces" }
    result.id = "omarchy.workspaces"
    result.source = workspaceWidgetSource
    if (displayLabels !== undefined) result.displayLabels = copy(displayLabels)
    return result
  }

  function monitorWorkspaceLayout(layout) {
    var result = { left: [], center: [], right: [] }
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var section = sections[s]
      var entries = layout && Array.isArray(layout[section]) ? layout[section] : []
      result[section] = entries.map(function(entry) {
        return entryId(entry) === "omarchy.workspaces" ? monitorWorkspaceEntry(entry) : entry
      })
    }
    return result
  }

  function fullLayout() {
    var layout = barConfig && barConfig.layout ? barConfig.layout : {}
    return {
      left: Array.isArray(layout.left) ? layout.left : [],
      center: Array.isArray(layout.center) ? layout.center : [],
      right: Array.isArray(layout.right) ? layout.right : []
    }
  }

  function monitorGlyphEntry(glyph, rotation, label) {
    return {
      id: "onnwee.monitor-glyph",
      source: monitorGlyphWidgetSource,
      glyph: glyph,
      rotation: rotation,
      accessibleLabel: label
    }
  }

  function secondaryLayout(glyph, rotation, label, displayLabels) {
    return {
      left: [
        monitorGlyphEntry(glyph, rotation, label),
        monitorWorkspaceEntry(existingEntry("omarchy.workspaces"), displayLabels)
      ],
      center: [],
      right: []
    }
  }

  function layoutFor(screenName) {
    var name = String(screenName || "")
    if (name === "DP-1") {
      return { layout: monitorWorkspaceLayout(fullLayout()), anchor: String(barConfig.centerAnchor || "") }
    }
    if (name === "DP-3") {
      return {
        layout: secondaryLayout("☿", 0, "Mercury monitor", {
          6: "٦",
          7: "٧",
          8: "٨"
        }),
        anchor: ""
      }
    }
    if (name === "HDMI-A-1") {
      return {
        layout: secondaryLayout("♄", 0, "Saturn monitor", {
          9: "九",
          10: "十",
          11: "十一"
        }),
        anchor: ""
      }
    }
    // Keep unlisted outputs restrained rather than exposing the full bar in an
    // unexpected place. Named layouts above are the only secondary surfaces.
    return { layout: { left: [], center: [], right: [] }, anchor: "" }
  }

  function applyConfig() {
    var config = barConfig && typeof barConfig === "object" ? barConfig : {}
    position = normalizePosition(config.position)
    requestedTransparent = config.transparent === true
    transparent = requestedTransparent
    layoutConfig = fullLayout()
    configured = true
  }

  onBarConfigChanged: applyConfig()
  Component.onCompleted: applyConfig()

  function run(command) {
    if (command) Util.execDetached(command)
  }

  function shellQuote(value) {
    return Util.shellQuote(value)
  }

  function registerClickTarget(target) {
    if (!target || clickTargets.indexOf(target) !== -1) return
    var next = clickTargets.slice()
    next.push(target)
    clickTargets = next
  }

  function unregisterClickTarget(target) {
    clickTargets = clickTargets.filter(function(item) { return item !== target })
  }

  function registerModuleSlot(slot) {
    if (!slot || moduleSlots.indexOf(slot) !== -1) return
    var next = moduleSlots.slice()
    next.push(slot)
    moduleSlots = next
  }

  function unregisterModuleSlot(slot) {
    moduleSlots = moduleSlots.filter(function(item) { return item !== slot })
  }

  function registerWidget(target, screenName) {
    if (!target) return
    for (var i = 0; i < liveWidgets.length; i++)
      if (liveWidgets[i].item === target) return
    var next = liveWidgets.slice()
    next.push({ item: target, screenName: String(screenName || "") })
    liveWidgets = next
  }

  function unregisterWidget(target) {
    liveWidgets = liveWidgets.filter(function(row) { return row.item !== target })
  }

  function moduleWidgets(pluginId) {
    var id = String(pluginId || "")
    var result = []
    for (var i = 0; i < liveWidgets.length; i++) {
      var item = liveWidgets[i].item
      if (item && String(item.moduleName || "") === id) result.push(item)
    }
    return result
  }

  function debugBarGeometry() {
    var widgets = barWidgetRegistry && barWidgetRegistry.widgets ? barWidgetRegistry.widgets : {}
    var result = []
    for (var i = 0; i < liveWidgets.length; i++) {
      var row = liveWidgets[i]
      result.push({
        id: row.item ? String(row.item.moduleName || "") : "",
        screen: row.screenName,
        width: row.item ? Math.round(row.item.implicitWidth || 0) : 0,
        height: row.item ? Math.round(row.item.implicitHeight || 0) : 0,
        visible: !!row.item && row.item.visible === true
      })
    }
    return result
  }

  function focusedScreenName() {
    return Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name || "") : ""
  }

  function panelWidget(pluginId) {
    var candidates = []
    var focused = focusedScreenName()
    for (var i = 0; i < liveWidgets.length; i++) {
      var row = liveWidgets[i]
      var item = row.item
      if (!item || String(item.moduleName || "") !== String(pluginId || "")) continue
      if (typeof item.open !== "function" || typeof item.close !== "function") continue
      candidates.push(row)
    }
    var open = candidates.filter(function(row) { return row.item.opened === true })
    var pool = open.length ? open : candidates
    for (var j = 0; j < pool.length; j++)
      if (pool[j].screenName === focused) return pool[j].item
    return pool.length ? pool[0].item : null
  }

  function summonBarWidget(pluginId) {
    var item = panelWidget(pluginId)
    if (!item) return false
    item.open()
    return true
  }

  function hideBarWidget(pluginId) {
    var item = panelWidget(pluginId)
    if (!item) return false
    item.close()
    return true
  }

  function isBarWidgetOpen(pluginId) {
    var item = panelWidget(pluginId)
    return !!item && item.opened === true
  }

  function requestPopout(owner) {
    if (activePopout === owner) return
    if (activePopout && typeof activePopout.close === "function") activePopout.close()
    activePopout = owner
  }

  function releasePopout(owner) {
    if (activePopout === owner) activePopout = null
  }

  // Tooltip surfaces are owned by the stock bar's more elaborate host. Keep
  // the widget contract intact without adding a second tooltip implementation.
  function showTooltip(target, text) { }
  function hideTooltip(target) { }
  function switchPanelFrom(owner, direction) { return false }

  Process {
    id: barHiddenProbe
    running: true
    command: ["bash", "-c", "[[ -f $HOME/.local/state/omarchy/toggles/bar-off ]] && echo yes || echo no"]
    stdout: SplitParser {
      onRead: function(line) { root.barHidden = String(line).trim() === "yes" }
    }
  }

  FileView {
    path: root.stateHome + "/omarchy/toggles"
    watchChanges: true
    printErrors: false
    onFileChanged: barHiddenProbe.running = true
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      MonitorBar {
        required property var modelData
        monitorScreen: modelData
      }
    }
  }

  component MonitorBar: PanelWindow {
    id: monitorBar

    required property var monitorScreen
    readonly property string screenName: monitorScreen ? String(monitorScreen.name || "") : ""
    readonly property var monitorSpec: root.layoutFor(screenName)
    readonly property var adapter: root.barAdapter

    screen: monitorScreen
    visible: true
    exclusionMode: root.barHidden ? ExclusionMode.Ignore : ExclusionMode.Auto
    color: root.transparent ? "transparent" : root.background
    surfaceFormat.opaque: false
    implicitWidth: root.vertical ? root.barSize : 0
    implicitHeight: root.vertical ? 0 : root.barSize
    WlrLayershell.namespace: "omarchy-bar"
    WlrLayershell.layer: WlrLayer.Top

    margins {
      top: root.barHidden && root.position === "top" ? -root.barSize : 0
      bottom: root.barHidden && root.position === "bottom" ? -root.barSize : 0
      left: root.barHidden && root.position === "left" ? -root.barSize : 0
      right: root.barHidden && root.position === "right" ? -root.barSize : 0
    }

    anchors {
      top: root.position === "top" || root.vertical
      bottom: root.position === "bottom" || root.vertical
      left: root.position === "left" || !root.vertical
      right: root.position === "right" || !root.vertical
    }

    Loader {
      anchors.fill: parent
      sourceComponent: root.vertical ? verticalSurface : horizontalSurface
    }

    Component {
      id: horizontalSurface

      Item {
        anchors.fill: parent

        CenterModules {
          panel: monitorBar
          anchors.fill: parent
        }

        ModuleList {
          entries: monitorBar.monitorSpec.layout.left
          region: "left"
          screenName: monitorBar.screenName
          hostBar: monitorBar.adapter
          anchors.left: parent.left
          anchors.leftMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
        }

        ModuleList {
          entries: monitorBar.monitorSpec.layout.right
          region: "right"
          screenName: monitorBar.screenName
          hostBar: monitorBar.adapter
          anchors.right: parent.right
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
        }
      }
    }

    Component {
      id: verticalSurface

      Item {
        anchors.fill: parent

        CenterModules {
          panel: monitorBar
          anchors.fill: parent
        }

        ModuleList {
          entries: monitorBar.monitorSpec.layout.left
          region: "left"
          screenName: monitorBar.screenName
          hostBar: monitorBar.adapter
          anchors.top: parent.top
          anchors.topMargin: Style.space(8)
          anchors.horizontalCenter: parent.horizontalCenter
        }

        ModuleList {
          entries: monitorBar.monitorSpec.layout.right
          region: "right"
          screenName: monitorBar.screenName
          hostBar: monitorBar.adapter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(8)
          anchors.horizontalCenter: parent.horizontalCenter
        }
      }
    }
  }

  component CenterModules: Item {
    id: centerModules
    required property var panel
    readonly property var entries: panel ? panel.monitorSpec.layout.center : []
    readonly property string anchorId: panel ? String(panel.monitorSpec.anchor || "") : ""
    readonly property int anchorIndex: root.entryIndex(entries, anchorId)
    readonly property bool hasAnchor: anchorIndex >= 0

    ModuleList {
      visible: !centerModules.hasAnchor
      entries: centerModules.entries
      region: "center"
      screenName: centerModules.panel ? centerModules.panel.screenName : ""
      hostBar: centerModules.panel ? centerModules.panel.adapter : null
      anchors.centerIn: parent
    }

    ModuleList {
      visible: centerModules.hasAnchor
      entries: centerModules.entries.slice(0, centerModules.anchorIndex)
      region: "center"
      screenName: centerModules.panel ? centerModules.panel.screenName : ""
      hostBar: centerModules.panel ? centerModules.panel.adapter : null
      anchors.right: anchorModule.left
      anchors.verticalCenter: anchorModule.verticalCenter
    }

    ModuleSlot {
      id: anchorModule
      visible: centerModules.hasAnchor
      entry: centerModules.hasAnchor ? centerModules.entries[centerModules.anchorIndex] : ({ id: "" })
      region: "center"
      screenName: centerModules.panel ? centerModules.panel.screenName : ""
      hostBar: centerModules.panel ? centerModules.panel.adapter : null
      anchors.centerIn: parent
    }

    ModuleList {
      visible: centerModules.hasAnchor
      entries: centerModules.entries.slice(centerModules.anchorIndex + 1)
      region: "center"
      screenName: centerModules.panel ? centerModules.panel.screenName : ""
      hostBar: centerModules.panel ? centerModules.panel.adapter : null
      anchors.left: anchorModule.right
      anchors.verticalCenter: anchorModule.verticalCenter
    }
  }

  component ModuleList: Loader {
    id: moduleList
    property var entries: []
    property string region: ""
    property string screenName: ""
    property var hostBar: null

    visible: entries.length > 0
    active: visible
    sourceComponent: root.vertical ? verticalModuleList : horizontalModuleList
    width: item ? item.implicitWidth : 0
    height: item ? item.implicitHeight : 0

    Component {
      id: horizontalModuleList
      Row {
        spacing: 0
        Repeater {
          model: moduleList.entries
          ModuleSlot {
            required property var modelData
            entry: modelData
            region: moduleList.region
            screenName: moduleList.screenName
            hostBar: moduleList.hostBar
          }
        }
      }
    }

    Component {
      id: verticalModuleList
      Column {
        spacing: 0
        Repeater {
          model: moduleList.entries
          ModuleSlot {
            required property var modelData
            entry: modelData
            region: moduleList.region
            screenName: moduleList.screenName
            hostBar: moduleList.hostBar
          }
        }
      }
    }
  }

  function entryIndex(entries, id) {
    if (!Array.isArray(entries) || !id) return -1
    for (var i = 0; i < entries.length; i++)
      if (entryId(entries[i]) === id) return i
    return -1
  }

  component ModuleSlot: Item {
    id: slot
    required property var entry
    property string region: ""
    property string screenName: ""
    property var hostBar: null
    readonly property string moduleName: root.entryId(entry)
    readonly property var moduleSettings: root.entrySettings(entry)
    readonly property string qmlSource: root.customModuleSource(entry)
    readonly property bool qmlCustom: qmlSource !== ""
    readonly property var registryComponent: {
      // Revision is intentionally read here: the registry's map is replaced
      // asynchronously as each manifest component finishes loading.
      var revision = root.barWidgetRegistry ? root.barWidgetRegistry.revision : 0
      var serial = root.registrySerial
      var widgets = root.barWidgetRegistry && root.barWidgetRegistry.widgets
        ? root.barWidgetRegistry.widgets : {}
      if (slot.qmlCustom) return null
      return widgets[slot.moduleName] ? widgets[slot.moduleName].component : null
    }
    readonly property bool registered: !!registryComponent
    readonly property var activeItem: qmlCustom ? qmlLoader.item : widgetLoader.item

    implicitWidth: activeItem && activeItem.visible !== false ? activeItem.implicitWidth : 0
    implicitHeight: activeItem && activeItem.visible !== false ? activeItem.implicitHeight : 0
    width: implicitWidth
    height: implicitHeight

    Loader {
      id: widgetLoader
      active: slot.registered
      sourceComponent: slot.registered ? slot.registryComponent : null
      anchors.fill: parent
      onLoaded: {
        slot.injectProps()
        root.registerWidget(item, slot.screenName)
        Qt.callLater(slot.injectProps)
      }
    }

    Loader {
      id: qmlLoader
      active: slot.qmlCustom
      source: slot.qmlCustom ? slot.qmlSource : ""
      anchors.fill: parent
      onLoaded: {
        slot.injectProps()
        root.registerWidget(item, slot.screenName)
        Qt.callLater(slot.injectProps)
      }
    }

    Component.onCompleted: root.registerModuleSlot(slot)
    Component.onDestruction: {
      root.unregisterWidget(slot.activeItem)
      root.unregisterModuleSlot(slot)
    }
    onModuleSettingsChanged: slot.injectProps()
    onScreenNameChanged: slot.injectProps()

    function injectProps() {
      var target = activeItem
      if (!target) return
      if ("bar" in target && slot.hostBar) target.bar = slot.hostBar
      if ("moduleName" in target) target.moduleName = moduleName
      if ("settings" in target) target.settings = moduleSettings
      // Only monitor-aware widgets opt in to this property. The presence
      // check keeps stock and third-party widgets untouched.
      if ("screenName" in target) target.screenName = slot.screenName
    }
  }
}
