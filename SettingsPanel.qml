// SPDX-License-Identifier: MIT

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "MonitorBarModel.js" as MonitorBarModel
import "I18n.js" as I18n

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var pluginRegistry: null
  property var barWidgetRegistry: null
  readonly property string locale: I18n.currentLocale()
  property bool closingFromHost: false

  property var draft: MonitorBarModel.defaultConfig([])
  property string position: "top"
  property bool transparent: false
  property string selectedMonitor: ""
  property int draftSerial: 0
  property int validationSerial: 0
  property string baselineSnapshot: ""
  property string externalSnapshot: ""
  property bool externalConflict: false
  property bool writingConfig: false
  property bool closeConfirmOpen: false
  property string syncState: "idle"
  property string syncMessage: I18n.t(locale, "sync.notChecked")
  property string syncDetail: ""
  property bool restartArmed: false
  property var modalReturnFocus: null

  readonly property color foreground: Color.foreground
  readonly property color background: Color.background
  readonly property color accent: Color.accent
  readonly property color urgent: Color.urgent
  readonly property string fontFamily: Style.font.family
  readonly property bool compact: window.width < 760
  readonly property var selectedOutput: {
    var serial = draftSerial
    return draft && draft.outputs ? draft.outputs[selectedMonitor] : null
  }
  readonly property string validationError: validateDraft()
  readonly property bool dirty: snapshot() !== baselineSnapshot
  readonly property string sourceDir: manifest && manifest.__sourceDir ? String(manifest.__sourceDir) : ""
  readonly property string sourceError: sourceDir ? "" : I18n.t(locale, "sync.sourceUnavailable")
  readonly property bool canRestart: !syncProcess.running
    && !dirty && !validationError && !externalConflict
    && (syncState === "idle" || syncState === "current" || syncState === "stale")
  readonly property bool modalOpen: closeConfirmOpen || restartArmed

  ListModel { id: monitorModel }

  function clone(value) { return JSON.parse(JSON.stringify(value)) }

  function snapshot() {
    var serial = draftSerial + validationSerial
    return JSON.stringify({ position: position, transparent: transparent, monitor: draft })
  }

  function draftSnapshotFromShell(config) {
    config = config || ({})
    return JSON.stringify({
      position: config.bar && typeof config.bar.position === "string" ? config.bar.position : "top",
      transparent: !!(config.bar && config.bar.transparent),
      monitor: MonitorBarModel.configFromShell(config, connectedNames())
    })
  }

  function relevantShellSnapshot(config) {
    config = config || ({})
    return JSON.stringify({
      barId: config.bar && typeof config.bar.id === "string" ? config.bar.id : "",
      position: config.bar && typeof config.bar.position === "string" ? config.bar.position : "top",
      transparent: !!(config.bar && config.bar.transparent),
      monitor: MonitorBarModel.configFromShell(config, connectedNames())
    })
  }

  function connectedNames() {
    var names = []
    var screens = Quickshell.screens || []
    for (var i = 0; i < screens.length; i++) {
      var name = String(screens[i].name || "")
      if (name && names.indexOf(name) < 0) names.push(name)
    }
    return names
  }

  function isConnected(name) { return connectedNames().indexOf(String(name)) >= 0 }

  function refreshMonitors() {
    var names = connectedNames()
    var outputs = draft && draft.outputs ? draft.outputs : ({})
    Object.keys(outputs).forEach(function(name) {
      if (names.indexOf(name) < 0) names.push(name)
    })
    names.sort()
    monitorModel.clear()
    for (var i = 0; i < names.length; i++) {
      var name = names[i]
      var configured = outputs[name] !== undefined
      var output = configured ? outputs[name] : { mode: "hidden" }
      monitorModel.append({
        name: name,
        connected: isConnected(name),
        configured: configured,
        primary: draft.primary === name,
        mode: output.mode || "hidden"
      })
    }
    if (!selectedMonitor || names.indexOf(selectedMonitor) < 0)
      selectedMonitor = draft.primary && names.indexOf(draft.primary) >= 0 ? draft.primary : (names[0] || "")
  }

  function ensureSelectedOutput() {
    if (!selectedMonitor) return null
    if (!draft.outputs[selectedMonitor]) draft.outputs[selectedMonitor] = { mode: "hidden" }
    return draft.outputs[selectedMonitor]
  }

  function selectMonitor(name) {
    selectedMonitor = String(name)
    restartArmed = false
    draftSerial++
  }

  function focusMonitorButton(index) {
    if (root.compact || index < 0 || index >= monitorModel.count) return
    monitorList.currentIndex = index
    monitorList.positionViewAtIndex(index, ListView.Contain)
    var button = monitorList.itemAtIndex(index)
    if (button) button.forceActiveFocus()
  }

  function focusWorkspaceControl(index, control) {
    Qt.callLater(function() {
      var count = workspaceRepeater.count
      if (count === 0) {
        addWorkspaceButton.forceActiveFocus()
        return
      }
      var row = workspaceRepeater.itemAt(Math.max(0, Math.min(index, count - 1)))
      if (!row) return
      var target = control === "remove" ? row.removeButton : row.idField
      if (target) target.forceActiveFocus()
    })
  }

  function ensureFocusedVisible(item) {
    if (!item || !detailScroll.visible || !detailColumn.visible) return
    var ancestor = item
    while (ancestor && ancestor !== detailColumn) ancestor = ancestor.parent
    if (ancestor !== detailColumn) return
    var point = item.mapToItem(detailColumn, 0, 0)
    if (point.x + item.width < 0 || point.x > detailColumn.width) return
    var flick = detailScroll.contentItem
    if (!flick || flick.contentY === undefined) return
    var margin = Style.space(8)
    var top = point.y - margin
    var bottom = point.y + item.height + margin
    if (top < flick.contentY) flick.contentY = Math.max(0, top)
    else if (bottom > flick.contentY + flick.height)
      flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), bottom - flick.height)
  }

  function setMode(mode) {
    var output = ensureSelectedOutput()
    if (!output) return
    if (selectedMonitor === draft.primary) mode = "full"
    output.mode = mode
    if (mode === "minimal") {
      if (typeof output.glyph !== "string") output.glyph = ""
      if (!Array.isArray(output.workspaces)) output.workspaces = []
    }
    draftSerial++
    refreshMonitors()
  }

  function positionLabel(value) {
    return I18n.t(locale, "position." + value)
  }

  function positionOptions() {
    return [
      { value: "top", label: positionLabel("top") },
      { value: "right", label: positionLabel("right") },
      { value: "bottom", label: positionLabel("bottom") },
      { value: "left", label: positionLabel("left") }
    ]
  }

  function modeLabel(value) {
    return I18n.t(locale, "mode." + value)
  }

  function makePrimary() {
    if (!selectedMonitor) return
    ensureSelectedOutput()
    draft.primary = selectedMonitor
    draft.outputs[selectedMonitor].mode = "full"
    draftSerial++
    refreshMonitors()
    Qt.callLater(function() { modeGroup.forceActiveFocus() })
  }

  function addWorkspace() {
    var output = ensureSelectedOutput()
    if (!output || output.mode !== "minimal") return
    if (!Array.isArray(output.workspaces)) output.workspaces = []
    var candidate = 1
    var used = {}
    Object.keys(draft.outputs).forEach(function(name) {
      var rows = draft.outputs[name].workspaces || []
      for (var i = 0; i < rows.length; i++) used[Number(rows[i].id)] = true
    })
    while (used[candidate]) candidate++
    output.workspaces.push({ id: candidate, label: String(candidate) })
    draftSerial++
    validationSerial++
    focusWorkspaceControl(output.workspaces.length - 1, "id")
  }

  function removeWorkspace(index) {
    var output = selectedOutput
    if (!output || !Array.isArray(output.workspaces)) return
    output.workspaces.splice(index, 1)
    draftSerial++
    validationSerial++
    focusWorkspaceControl(index, "remove")
  }

  function validateDraft() {
    var serial = validationSerial + draftSerial
    if (!draft.primary || !draft.outputs[draft.primary]) return I18n.t(locale, "validation.choosePrimary")
    if (draft.outputs[draft.primary].mode !== "full") return I18n.t(locale, "validation.primaryFull")
    var used = {}
    var names = Object.keys(draft.outputs)
    for (var n = 0; n < names.length; n++) {
      var output = draft.outputs[names[n]]
      if (output.mode !== "minimal") continue
      var rows = Array.isArray(output.workspaces) ? output.workspaces : []
      for (var i = 0; i < rows.length; i++) {
        var id = rows[i].id
        if (typeof id !== "number" || !Number.isSafeInteger(id) || id <= 0 || id > 2147483647)
          return I18n.t(locale, "validation.workspaceIdRange")
        if (used[id]) return I18n.t(locale, "validation.workspaceIdDuplicate", { id: id })
        used[id] = true
        if (typeof rows[i].label !== "string") return I18n.t(locale, "validation.workspaceLabel")
      }
    }
    return ""
  }

  function loadDraft() {
    var config = shell && shell.shellConfig ? shell.shellConfig : ({})
    draft = MonitorBarModel.configFromShell(config, connectedNames())
    position = config.bar && typeof config.bar.position === "string" ? config.bar.position : "top"
    transparent = !!(config.bar && config.bar.transparent)
    selectedMonitor = draft.primary
    draftSerial++
    validationSerial++
    refreshMonitors()
    baselineSnapshot = snapshot()
    externalSnapshot = relevantShellSnapshot(config)
    externalConflict = false
  }

  function save() {
    if (validationError || externalConflict || !shell || typeof shell.mutateShellConfig !== "function") return
    var savedMonitor = MonitorBarModel.normalizeConfig(clone(draft))
    var savedPosition = position
    var savedTransparent = transparent
    writingConfig = true
    try {
      shell.mutateShellConfig(function(config) {
        if (!config.bar || typeof config.bar !== "object" || Array.isArray(config.bar)) config.bar = {}
        config.bar.id = "patrickfanella.monitor-bar"
        config.bar.position = savedPosition
        config.bar.transparent = savedTransparent
        config[MonitorBarModel.CONFIG_KEY] = savedMonitor
      })
    } finally {
      writingConfig = false
    }
    draft = savedMonitor
    draftSerial++
    baselineSnapshot = snapshot()
    externalSnapshot = relevantShellSnapshot(shell.shellConfig)
    refreshMonitors()
  }

  function handleShellConfigChanged() {
    if (writingConfig || !shell) return
    var nextSnapshot = relevantShellSnapshot(shell.shellConfig)
    if (nextSnapshot === externalSnapshot) return
    if (!window.visible) {
      externalSnapshot = nextSnapshot
      return
    }
    if (dirty) {
      externalSnapshot = nextSnapshot
      externalConflict = true
    } else {
      loadDraft()
    }
  }

  function reloadExternal() {
    loadDraft()
    closeConfirmOpen = false
    Qt.callLater(function() { closeButton.forceActiveFocus() })
  }

  function rebaseDraft() {
    if (!shell) return
    baselineSnapshot = draftSnapshotFromShell(shell.shellConfig)
    externalSnapshot = relevantShellSnapshot(shell.shellConfig)
    externalConflict = false
    Qt.callLater(function() { closeButton.forceActiveFocus() })
  }

  function resetLifecycleState() {
    restartArmed = false
    closeConfirmOpen = false
    modalReturnFocus = null
    externalConflict = false
    if (!syncProcess.running) {
      syncState = "idle"
      syncMessage = sourceError || I18n.t(locale, "sync.notChecked")
      syncDetail = sourceError
    }
  }

  function open(payloadJson) {
    closingFromHost = false
    resetLifecycleState()
    loadDraft()
    window.visible = true
    Qt.callLater(function() { closeButton.forceActiveFocus() })
  }

  function close() {
    resetLifecycleState()
    closingFromHost = true
    window.visible = false
    closingFromHost = false
  }

  function requestClose() {
    if (dirty) {
      openCloseConfirm()
      return
    }
    hidePanel()
  }

  function rememberModalFocus() {
    modalReturnFocus = window.activeFocusItem
  }

  function restoreModalFocus() {
    var target = modalReturnFocus
    modalReturnFocus = null
    Qt.callLater(function() {
      if (target && target.visible && target.enabled) target.forceActiveFocus()
      else closeButton.forceActiveFocus()
    })
  }

  function openCloseConfirm() {
    rememberModalFocus()
    closeConfirmOpen = true
    Qt.callLater(function() { cancelCloseButton.forceActiveFocus() })
  }

  function cancelCloseConfirm() {
    closeConfirmOpen = false
    restoreModalFocus()
  }

  function cancelRestart() {
    restartArmed = false
    restoreModalFocus()
  }

  function hidePanel() {
    if (shell && typeof shell.hide === "function") shell.hide((manifest && manifest.id) || "patrickfanella.monitor-bar")
    else window.visible = false
  }

  function saveAndClose() {
    if (validationError || externalConflict) return
    save()
    closeConfirmOpen = false
    hidePanel()
  }

  function discardAndClose() {
    closeConfirmOpen = false
    hidePanel()
  }

  function runCheck() {
    if (syncProcess.running || !sourceDir) return
    syncState = "checking"
    syncMessage = I18n.t(locale, "sync.checkingStock")
    syncDetail = ""
    syncProcess.action = "check"
    syncProcess.command = ["python3", sourceDir + "/tools/sync_stock_bar.py", "--check"]
    syncProcess.running = true
  }

  function runSync() {
    if (syncProcess.running || !sourceDir) return
    syncState = "syncing"
    syncMessage = I18n.t(locale, "sync.syncingStock")
    syncDetail = ""
    syncProcess.action = "sync"
    syncProcess.command = ["python3", sourceDir + "/tools/sync_stock_bar.py"]
    syncProcess.running = true
  }

  function finishSync(exitCode) {
    var detail = String(syncProcess.stderrText || "").trim()
    if (syncProcess.action === "check") {
      if (exitCode === 0) { syncState = "current"; syncMessage = I18n.t(locale, "sync.current") }
      else if (detail.indexOf("stale generated") >= 0) { syncState = "stale"; syncMessage = I18n.t(locale, "sync.stale") }
      else if (detail.indexOf("changed: expected sha256") >= 0) { syncState = "unsupported"; syncMessage = I18n.t(locale, "sync.unsupported") }
      else { syncState = "error"; syncMessage = detail || I18n.t(locale, "sync.checkFailed") }
    } else {
      if (exitCode === 0) { syncState = "current"; syncMessage = I18n.t(locale, "sync.syncedRestart") }
      else if (detail.indexOf("changed: expected sha256") >= 0) { syncState = "unsupported"; syncMessage = I18n.t(locale, "sync.unsupported") }
      else { syncState = "error"; syncMessage = detail || I18n.t(locale, "sync.syncFailed") }
    }
    syncDetail = detail || syncMessage
  }

  function restartNow() {
    if (!canRestart) return
    restartArmed = false
    Quickshell.execDetached(["omarchy-restart-shell"])
    hidePanel()
  }

  function armRestart() {
    if (!canRestart) return
    rememberModalFocus()
    restartConfirm.selectedIndex = 0
    restartArmed = true
    Qt.callLater(function() { restartModal.forceActiveFocus() })
  }

  Process {
    id: syncProcess
    property string action: ""
    property string stderrText: ""
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: syncProcess.stderrText = String(text || "")
    }
    onRunningChanged: if (running) stderrText = ""
    onExited: function(exitCode) { Qt.callLater(function() { root.finishSync(exitCode) }) }
  }

  Connections {
    target: Quickshell
    function onScreensChanged() {
      var config = root.shell && root.shell.shellConfig ? root.shell.shellConfig : ({})
      var canonical = MonitorBarModel.hasCanonicalConfig(config)
      if (!canonical && !root.dirty) root.loadDraft()
      else root.refreshMonitors()
    }
  }

  Connections {
    target: root.shell
    function onShellConfigChanged() { root.handleShellConfigChanged() }
  }

  Timer {
    interval: 10000
    running: root.restartArmed
    onTriggered: root.cancelRestart()
  }

  FloatingWindow {
    id: window
    title: I18n.t(root.locale, "settings.title")
    color: root.background
    implicitWidth: 720
    implicitHeight: 600
    minimumSize: Qt.size(560, 460)
    maximumSize: Qt.size(820, 700)

    onVisibleChanged: {
      if (visible) return
      if (!root.closingFromHost && root.dirty) {
        visible = true
        root.openCloseConfirm()
        return
      }
      if (!root.closingFromHost && root.shell && typeof root.shell.hide === "function")
        root.shell.hide((root.manifest && root.manifest.id) || "patrickfanella.monitor-bar")
      root.resetLifecycleState()
    }

    FocusScope {
      id: keyScope
      anchors.fill: parent
      focus: true
      Keys.priority: Keys.AfterItem
      Keys.onPressed: function(event) {
        if (root.closeConfirmOpen) {
          if (event.key === Qt.Key_Escape) {
            root.cancelCloseConfirm()
            event.accepted = true
          }
          return
        }
        if (root.restartArmed) {
          if (restartConfirm.handleKey(event)) event.accepted = true
          return
        }
        if (event.key === Qt.Key_Escape) { root.requestClose(); event.accepted = true }
        else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
          root.save(); event.accepted = true
        }
      }

      ColumnLayout {
        id: mainContent
        anchors.fill: parent
        anchors.margins: Style.space(16)
        spacing: Style.space(12)
        enabled: !root.modalOpen

        GridLayout {
          Layout.fillWidth: true
          columns: root.compact ? 1 : 2
          rowSpacing: Style.space(10)
          columnSpacing: Style.space(10)

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(2)
            Text { text: I18n.t(root.locale, "settings.heading"); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.iconLarge; font.bold: true }
            Text { text: I18n.t(root.locale, "settings.subtitle"); color: Qt.darker(root.foreground, 1.45); font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
          }
          RowLayout {
            Layout.fillWidth: root.compact
            Layout.alignment: Qt.AlignRight
            Text {
              text: root.validationError ? I18n.t(root.locale, "status.fixValidation") : (root.dirty ? I18n.t(root.locale, "status.unsaved") : I18n.t(root.locale, "status.saved"))
              color: root.validationError ? root.urgent : Qt.darker(root.foreground, 1.35)
              font.family: root.fontFamily; font.pixelSize: Style.font.caption
            }
            Item { Layout.fillWidth: root.compact }
            Button {
              text: I18n.t(root.locale, "action.save")
              iconText: "󰆓"
              bordered: true
              focusable: true
              active: root.dirty && !root.validationError && !root.externalConflict
              enabled: root.dirty && !root.validationError && !root.externalConflict
              opacity: enabled ? 1 : 0.45
              Accessible.role: Accessible.Button
              Accessible.name: I18n.t(root.locale, "a11y.saveSettings")
              Accessible.description: root.externalConflict ? I18n.t(root.locale, "a11y.resolveExternalBeforeSave") : ""
              onClicked: root.save()
            }
            Button {
              id: closeButton
              text: I18n.t(root.locale, "action.close")
              iconText: "󰅖"
              bordered: true
              focusable: true
              Accessible.role: Accessible.Button
              Accessible.name: I18n.t(root.locale, "a11y.closeSettings")
              Accessible.description: root.dirty ? I18n.t(root.locale, "a11y.closeWithChanges") : I18n.t(root.locale, "a11y.closePanel")
              onClicked: root.requestClose()
            }
          }
        }

        PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }

        GridLayout {
          Layout.fillWidth: true
          columns: root.compact ? 1 : 4
          rowSpacing: Style.space(10)
          columnSpacing: Style.space(18)
          Text { text: I18n.t(root.locale, "position.heading"); color: Qt.darker(root.foreground, 1.3); font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
          ButtonGroup {
            id: positionGroup
            visible: !root.compact
            options: root.positionOptions()
            value: root.position
            Accessible.role: Accessible.Grouping
            Accessible.name: I18n.t(root.locale, "position.label")
            Accessible.description: I18n.t(root.locale, "position.current", { position: root.positionLabel(root.position) })
            onChanged: function(value) { root.position = value }
          }
          Dropdown {
            id: positionDropdown
            visible: root.compact
            Layout.fillWidth: true
            label: I18n.t(root.locale, "position.label")
            options: root.positionOptions()
            value: root.position
            Accessible.role: Accessible.ComboBox
            Accessible.name: I18n.t(root.locale, "position.label")
            Accessible.description: I18n.t(root.locale, "common.currentValue", { value: positionDropdown.currentLabel() })
            onChanged: function(value) { root.position = value }
          }
          Item { visible: !root.compact; Layout.fillWidth: true }
          Toggle {
            Layout.fillWidth: root.compact
            label: I18n.t(root.locale, "appearance.transparent")
            description: root.compact ? I18n.t(root.locale, "appearance.transparentDescription") : ""
            checked: root.transparent
            Accessible.role: Accessible.CheckBox
            Accessible.name: I18n.t(root.locale, "appearance.transparentA11y")
            Accessible.checked: root.transparent
            onClicked: root.transparent = !root.transparent
          }
        }

        Dropdown {
          id: monitorDropdown
          visible: root.compact
          Layout.fillWidth: true
          label: I18n.t(root.locale, "monitor.label")
          options: {
            var rows = []
            for (var i = 0; i < monitorModel.count; i++) {
              var row = monitorModel.get(i)
              rows.push({ value: row.name, label: I18n.t(root.locale, row.connected ? "monitor.namedOnline" : "monitor.namedOffline", { name: row.name }) })
            }
            return rows
          }
          value: root.selectedMonitor
          Accessible.role: Accessible.ComboBox
          Accessible.name: I18n.t(root.locale, "monitor.label")
          Accessible.description: I18n.t(root.locale, "common.currentValue", { value: monitorDropdown.currentLabel() })
          onChanged: function(value) { root.selectMonitor(value) }
        }

        RowLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.space(14)

          BorderSurface {
            visible: !root.compact
            Layout.preferredWidth: 230
            Layout.fillHeight: true
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.025)
            borderSpec: Border.flat(Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12), 1)
            radius: Style.cornerRadius

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(6)
              Text { text: I18n.t(root.locale, "monitor.heading"); color: Qt.darker(root.foreground, 1.35); font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
              ListView {
                id: monitorList
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Style.space(4)
                clip: true
                model: monitorModel
                delegate: Button {
                  required property string name
                  required property bool connected
                  required property bool configured
                  required property bool primary
                  required property string mode
                  required property int index
                  width: ListView.view.width
                  text: primary
                    ? I18n.t(root.locale, "monitor.primaryFull", { name: name })
                    : (configured
                      ? I18n.t(root.locale, "monitor.namedMode", { name: name, mode: root.modeLabel(mode) })
                      : I18n.t(root.locale, "monitor.hiddenNew", { name: name }))
                  iconText: connected ? "󰍹" : "󰍺"
                  leftAlign: true
                  bordered: true
                  selected: root.selectedMonitor === name
                  focusable: true
                  tooltipText: I18n.t(root.locale, "monitor.summary", {
                    primary: primary ? I18n.t(root.locale, "monitor.primary") : I18n.t(root.locale, "monitor.secondary"),
                    mode: configured ? root.modeLabel(mode) : I18n.t(root.locale, "monitor.hiddenUnsaved"),
                    connection: connected ? I18n.t(root.locale, "monitor.online") : I18n.t(root.locale, "monitor.offline")
                  })
                  Accessible.name: I18n.t(root.locale, "monitor.accessibleSummary", { name: name, summary: tooltipText })
                  Accessible.role: Accessible.RadioButton
                  Accessible.checked: selected
                  Accessible.selected: selected
                  onActiveFocusChanged: if (activeFocus) {
                    monitorList.currentIndex = index
                    monitorList.positionViewAtIndex(index, ListView.Contain)
                  }
                  onClicked: {
                    root.selectMonitor(name)
                    root.focusMonitorButton(index)
                  }
                }
              }
            }
          }

          BorderSurface {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            borderSpec: Border.flat(Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12), 1)
            radius: Style.cornerRadius

            ScrollView {
              id: detailScroll
              anchors.fill: parent
              anchors.margins: Style.space(12)
              clip: true
              ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

              ColumnLayout {
                id: detailColumn
                width: parent.width
                spacing: Style.space(14)

                RowLayout {
                  Layout.fillWidth: true
                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text { text: root.selectedMonitor || I18n.t(root.locale, "monitor.none"); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.subtitle; font.bold: true }
                    Text {
                      text: !root.selectedMonitor ? ""
                        : I18n.t(root.locale,
                            root.selectedMonitor === root.draft.primary ? "monitor.connectionPrimary" : "monitor.connection",
                            { connection: root.isConnected(root.selectedMonitor) ? I18n.t(root.locale, "monitor.connected") : I18n.t(root.locale, "monitor.offline") })
                      color: root.isConnected(root.selectedMonitor) ? root.accent : Qt.darker(root.foreground, 1.5)
                      font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
                    }
                  }
                  Button {
                    visible: root.selectedMonitor && root.selectedMonitor !== root.draft.primary
                    text: I18n.t(root.locale, "monitor.makePrimary")
                    bordered: true
                    focusable: true
                    Accessible.role: Accessible.Button
                    Accessible.name: I18n.t(root.locale, "monitor.makeNamedPrimary", { name: root.selectedMonitor })
                    onClicked: root.makePrimary()
                  }
                }

                PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(7)
                  Text { text: I18n.t(root.locale, "mode.heading"); color: Qt.darker(root.foreground, 1.35); font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
                  ButtonGroup {
                    id: modeGroup
                    options: [
                      { value: "full", label: I18n.t(root.locale, "mode.full") },
                      { value: "minimal", label: I18n.t(root.locale, "mode.minimal") },
                      { value: "hidden", label: I18n.t(root.locale, "mode.hidden") }
                    ]
                    value: root.selectedOutput ? root.selectedOutput.mode : "hidden"
                    onChanged: function(value) { root.setMode(value) }
                    Accessible.role: Accessible.Grouping
                    Accessible.name: I18n.t(root.locale, "mode.forMonitor", { name: root.selectedMonitor })
                    Accessible.description: I18n.t(root.locale, "mode.current", { mode: root.modeLabel(modeGroup.value) })
                  }
                  Text {
                    visible: root.selectedMonitor === root.draft.primary
                    text: I18n.t(root.locale, "mode.primaryLocked")
                    color: Qt.darker(root.foreground, 1.45); font.family: root.fontFamily; font.pixelSize: Style.font.caption
                  }
                  Text {
                    visible: !root.selectedOutput
                    text: I18n.t(root.locale, "mode.unconfigured")
                    color: Qt.darker(root.foreground, 1.35); font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                  }
                }

                ColumnLayout {
                  visible: root.selectedOutput && root.selectedOutput.mode === "minimal"
                  Layout.fillWidth: true
                  spacing: Style.space(10)

                  Text { text: I18n.t(root.locale, "minimal.heading"); color: Qt.darker(root.foreground, 1.35); font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(10)
                    TextField {
                      id: glyphField
                      Layout.fillWidth: true
                      placeholderText: I18n.t(root.locale, "minimal.glyph")
                      text: root.selectedOutput && typeof root.selectedOutput.glyph === "string" ? root.selectedOutput.glyph : ""
                      Accessible.name: I18n.t(root.locale, "minimal.glyphFor", { name: root.selectedMonitor })
                      onActiveFocusChanged: if (activeFocus) root.ensureFocusedVisible(glyphField)
                      onTextEdited: {
                        if (root.selectedOutput) root.selectedOutput.glyph = text
                        root.validationSerial++
                      }
                    }
                    BorderSurface {
                      Layout.preferredWidth: 54
                      Layout.preferredHeight: 38
                      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
                      borderSpec: Border.flat(Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15), 1)
                      Text { anchors.centerIn: parent; text: glyphField.text || "·"; color: root.foreground; font.family: "Noto Sans Symbols 2"; font.pixelSize: Style.font.iconLarge }
                      Accessible.name: I18n.t(root.locale, "minimal.glyphPreview", { glyph: glyphField.text })
                    }
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    Text { text: I18n.t(root.locale, "workspace.heading"); color: Qt.darker(root.foreground, 1.35); font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Button { id: addWorkspaceButton; text: I18n.t(root.locale, "action.add"); iconText: "+"; bordered: true; focusable: true; Accessible.role: Accessible.Button; Accessible.name: I18n.t(root.locale, "workspace.add"); onActiveFocusChanged: if (activeFocus) root.ensureFocusedVisible(addWorkspaceButton); onClicked: root.addWorkspace() }
                  }

                  Repeater {
                    id: workspaceRepeater
                    model: root.selectedOutput && Array.isArray(root.selectedOutput.workspaces) ? root.selectedOutput.workspaces : []
                    delegate: RowLayout {
                      required property var modelData
                      required property int index
                      Layout.fillWidth: true
                      spacing: Style.space(8)
                      Accessible.role: Accessible.ListItem
                      Accessible.name: I18n.t(root.locale, "workspace.row", { row: index + 1 })

                      property alias idField: workspaceIdField
                      property alias removeButton: removeWorkspaceButton

                      TextField {
                        id: workspaceIdField
                        Layout.preferredWidth: 100
                        text: String(modelData.id)
                        placeholderText: I18n.t(root.locale, "workspace.id")
                        inputMethodHints: Qt.ImhDigitsOnly
                        Accessible.name: I18n.t(root.locale, "workspace.idRow", { row: index + 1 })
                        onActiveFocusChanged: if (activeFocus) root.ensureFocusedVisible(workspaceIdField)
                        onTextEdited: { modelData.id = Number(text); root.validationSerial++ }
                      }
                      TextField {
                        id: workspaceLabelField
                        Layout.fillWidth: true
                        text: String(modelData.label)
                        placeholderText: I18n.t(root.locale, "workspace.label")
                        Accessible.name: I18n.t(root.locale, "workspace.labelRow", { row: index + 1 })
                        onActiveFocusChanged: if (activeFocus) root.ensureFocusedVisible(workspaceLabelField)
                        onTextEdited: { modelData.label = text; root.validationSerial++ }
                      }
                      Button {
                        id: removeWorkspaceButton
                        text: I18n.t(root.locale, "action.remove")
                        iconText: "󰅖"
                        bordered: true
                        focusable: true
                        foreground: root.urgent
                        Accessible.role: Accessible.Button
                        Accessible.name: I18n.t(root.locale, "workspace.removeRow", { row: index + 1 })
                        onActiveFocusChanged: if (activeFocus) root.ensureFocusedVisible(removeWorkspaceButton)
                        onClicked: root.removeWorkspace(index)
                      }
                    }
                  }
                }

                Text {
                  visible: root.validationError !== ""
                  Layout.fillWidth: true
                  text: root.validationError
                  color: root.urgent
                  font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true
                  wrapMode: Text.WordWrap
                  Accessible.role: Accessible.AlertMessage
                  Accessible.name: text
                }
              }
            }
          }
        }

        PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }

        GridLayout {
          Layout.fillWidth: true
          columns: root.compact ? 1 : 4
          rowSpacing: Style.space(8)
          columnSpacing: Style.space(8)
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text { text: I18n.t(root.locale, "sync.heading"); color: Qt.darker(root.foreground, 1.35); font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
            Text {
              text: root.sourceError || root.syncMessage
              color: root.sourceError || root.syncState === "error" || root.syncState === "unsupported" ? root.urgent
                : root.syncState === "stale" ? root.accent : Qt.darker(root.foreground, 1.35)
              font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              Layout.fillWidth: true
              Accessible.role: root.sourceError || root.syncState === "error" || root.syncState === "unsupported" ? Accessible.AlertMessage : Accessible.StaticText
              Accessible.name: text
              Accessible.description: root.sourceError || root.syncDetail
            }
          }
          Button { Layout.fillWidth: root.compact; text: root.syncState === "checking" ? I18n.t(root.locale, "action.checking") : I18n.t(root.locale, "action.check"); bordered: true; focusable: true; enabled: !syncProcess.running && !!root.sourceDir; opacity: enabled ? 1 : 0.5; tooltipText: root.sourceError || root.syncDetail; Accessible.role: Accessible.Button; Accessible.name: I18n.t(root.locale, "sync.checkCopy"); Accessible.description: tooltipText; onClicked: root.runCheck() }
          Button { Layout.fillWidth: root.compact; text: root.syncState === "syncing" ? I18n.t(root.locale, "action.syncing") : I18n.t(root.locale, "action.sync"); bordered: true; focusable: true; enabled: !syncProcess.running && !!root.sourceDir; opacity: enabled ? 1 : 0.5; tooltipText: root.sourceError || root.syncDetail; Accessible.role: Accessible.Button; Accessible.name: I18n.t(root.locale, "sync.syncCopy"); Accessible.description: tooltipText; onClicked: root.runSync() }
          Button {
            Layout.fillWidth: root.compact
            text: I18n.t(root.locale, "action.restartShell")
            bordered: true
            focusable: true
            enabled: root.canRestart
            opacity: enabled ? 1 : 0.5
            Accessible.role: Accessible.Button
            Accessible.name: I18n.t(root.locale, "action.restartShell")
            Accessible.description: root.dirty ? I18n.t(root.locale, "restart.saveFirst") : (syncProcess.running ? I18n.t(root.locale, "restart.waitForTask") : I18n.t(root.locale, "restart.requiresConfirmation"))
            onClicked: root.armRestart()
          }
        }
      }

      FocusScope {
        id: restartModal
        anchors.fill: parent
        z: 90
        visible: root.restartArmed
        focus: visible
        Accessible.role: Accessible.Dialog
        Accessible.name: I18n.t(root.locale, "restart.confirmation")
        Accessible.description: I18n.t(root.locale, "restart.keyboardHelp")
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Space) {
            if (restartConfirm.selectedIndex === 0) root.cancelRestart()
            else root.restartNow()
            event.accepted = true
          } else if (restartConfirm.handleKey(event)) {
            event.accepted = true
          }
        }

        ConfirmDialog {
          id: restartConfirm
          anchors.fill: parent
          opened: root.restartArmed
          message: I18n.t(root.locale, "restart.prompt")
          cancelText: I18n.t(root.locale, "action.cancel")
          confirmText: I18n.t(root.locale, "action.restartNow")
          foreground: root.foreground
          fontFamily: root.fontFamily
          onCanceled: root.cancelRestart()
          onConfirmed: root.restartNow()
        }
      }

      FocusScope {
        id: closeConfirm
        anchors.fill: parent
        z: 100
        visible: root.closeConfirmOpen
        focus: visible
        Accessible.role: Accessible.Dialog
        Accessible.name: I18n.t(root.locale, "close.unsavedChanges")
        Keys.onEscapePressed: root.cancelCloseConfirm()

        Rectangle {
          anchors.fill: parent
          color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.82)
          MouseArea { anchors.fill: parent; onClicked: root.cancelCloseConfirm() }
        }

        BorderSurface {
          width: Math.min(parent.width - Style.space(32), Style.space(440))
          implicitHeight: closeContent.implicitHeight + Style.space(36)
          anchors.centerIn: parent
          color: root.background
          borderSpec: Border.flat(root.accent, Style.normalBorderWidth)
          radius: Style.cornerRadius

          MouseArea { anchors.fill: parent; onClicked: {} }

          ColumnLayout {
            id: closeContent
            anchors.fill: parent
            anchors.margins: Style.space(18)
            spacing: Style.space(14)

            Text {
              Layout.fillWidth: true
              text: I18n.t(root.locale, "close.savePrompt")
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              wrapMode: Text.WordWrap
            }
            Text {
              visible: root.validationError || root.externalConflict
              Layout.fillWidth: true
              text: root.validationError ? root.validationError : I18n.t(root.locale, "conflict.reloadBeforeSave")
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
              Accessible.role: Accessible.AlertMessage
            }
            GridLayout {
              Layout.fillWidth: true
              columns: root.compact ? 1 : 4
              rowSpacing: Style.space(8)
              columnSpacing: Style.space(8)
              Item { visible: !root.compact; Layout.fillWidth: true }
              Button { id: cancelCloseButton; Layout.fillWidth: root.compact; text: I18n.t(root.locale, "action.cancel"); bordered: true; focusable: true; Accessible.role: Accessible.Button; Accessible.name: I18n.t(root.locale, "close.cancel"); KeyNavigation.tab: discardCloseButton; KeyNavigation.backtab: saveCloseButton; onClicked: root.cancelCloseConfirm() }
              Button { id: discardCloseButton; Layout.fillWidth: root.compact; text: I18n.t(root.locale, "action.discard"); bordered: true; focusable: true; foreground: root.urgent; Accessible.role: Accessible.Button; Accessible.name: I18n.t(root.locale, "close.discard"); KeyNavigation.tab: saveCloseButton; KeyNavigation.backtab: cancelCloseButton; onClicked: root.discardAndClose() }
              Button { id: saveCloseButton; Layout.fillWidth: root.compact; text: I18n.t(root.locale, "action.save"); bordered: true; focusable: true; enabled: !root.validationError && !root.externalConflict; opacity: enabled ? 1 : 0.45; Accessible.role: Accessible.Button; Accessible.name: I18n.t(root.locale, "close.save"); Accessible.description: enabled ? "" : I18n.t(root.locale, "close.fixFirst"); KeyNavigation.tab: cancelCloseButton; KeyNavigation.backtab: discardCloseButton; onClicked: root.saveAndClose() }
            }
          }
        }
      }

      BorderSurface {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Style.space(16)
        z: 50
        visible: root.externalConflict && !root.closeConfirmOpen
        enabled: !root.modalOpen
        implicitHeight: conflictContent.implicitHeight + Style.space(20)
        color: root.background
        borderSpec: Border.flat(root.urgent, Style.normalBorderWidth)
        radius: Style.cornerRadius
        Accessible.role: Accessible.AlertMessage
        Accessible.name: I18n.t(root.locale, "conflict.detected")

        GridLayout {
          id: conflictContent
          anchors.fill: parent
          anchors.margins: Style.space(10)
          columns: root.compact ? 1 : 3
          rowSpacing: Style.space(8)
          columnSpacing: Style.space(8)
          Text { Layout.fillWidth: true; text: I18n.t(root.locale, "conflict.message"); color: root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap }
          Button { Layout.fillWidth: root.compact; text: I18n.t(root.locale, "action.reload"); bordered: true; focusable: true; Accessible.role: Accessible.Button; Accessible.name: I18n.t(root.locale, "conflict.reloadDiscard"); onClicked: root.reloadExternal() }
          Button { Layout.fillWidth: root.compact; text: I18n.t(root.locale, "action.rebase"); bordered: true; focusable: true; Accessible.role: Accessible.Button; Accessible.name: I18n.t(root.locale, "conflict.rebaseA11y"); onClicked: root.rebaseDraft() }
        }
      }
    }
  }
}
