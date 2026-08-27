// SPDX-License-Identifier: MIT
// Derived from Omarchy stock Workspaces.qml, Copyright (c) David Heinemeier Hansson.

import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// The stock widget deliberately has a small fixed fallback model. This copy
// keeps its rendering and dispatch behavior, while scoping the model to the
// monitor that owns the bar. Hyprland's workspace objects include persistent
// empty workspaces, so they remain visible without a second hard-coded list.
BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  // Injected by the monitor bar's ModuleSlot. An empty value is intentionally
  // treated as no matches rather than leaking every workspace onto every bar.
  property string screenName: ""

  // IDs and display-only labels are injected by minimal monitor layouts.
  // Without IDs this retains the stock live-monitor fallback.
  readonly property var configuredWorkspaceIds: root.setting("workspaceIds", null)
  readonly property var displayLabels: root.setting("displayLabels", ({}))

  function workspaceMonitorName(workspace) {
    if (!workspace || !workspace.monitor) return ""
    if (typeof workspace.monitor === "string") return workspace.monitor
    return String(workspace.monitor.name || "")
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function workspaceIds() {
    if (Array.isArray(root.configuredWorkspaceIds))
      return root.configuredWorkspaceIds.slice()

    var ids = []
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var workspace = values[i]
      var id = Number(workspace.id)
      if (id > 0 && workspaceMonitorName(workspace) === root.screenName)
        ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  function displayLabel(id) {
    var labels = root.displayLabels
    var key = String(id)
    return labels && labels[key] !== undefined
      ? String(labels[key])
      : (id === 10 ? "0" : key)
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property string displayText: root.displayLabel(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData

        bar: root.bar
        text: focused ? String.fromCodePoint(0xF14FB) : displayText
        opacity: occupied || focused ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        // Keep stock-sized single-glyph buttons, but give translated labels
        // enough room to breathe instead of clipping them inside 20px.
        fixedWidth: root.vertical
          ? root.barSize
          : (displayText.length > 1
            ? Math.max(Style.space(20), labelWidth + scaledHorizontalMargin * 2)
            : Style.space(20))
        fixedHeight: root.barSize
        Accessible.role: Accessible.Button
        Accessible.name: "Workspace " + displayText
        Accessible.description: occupied ? "Occupied workspace on " + root.screenName : "Empty workspace on " + root.screenName
        Accessible.selected: focused
        Accessible.onPressAction: root.focusWorkspace(modelData)
        onPressed: function() { root.focusWorkspace(modelData) }
      }
    }
  }
}
