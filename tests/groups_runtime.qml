import QtQuick
import Quickshell
import "groups" as Groups
import "monitor" as Monitor
ShellRoot {
  QtObject {
    id: hostShell
    property var bar: null
    property var barConfig: ({layout: {left: [], center: [], right: []}})
    function mutateShellConfig(callback) {
      var config = {bar: JSON.parse(JSON.stringify(barConfig))}
      callback(config)
      barConfig = config.bar
      return true
    }
  }
  Item {
    id: hostBar
    property var shell: hostShell
    property var barConfig: hostShell.barConfig
    property var moduleSlots: [{moduleName: "test.widget", activeItem: {shelfishStatus: "ok"}}]
    property color foreground: "white"
    property color background: "black"
    property color urgent: "red"
    property string fontFamily: "monospace"
    property string position: "top"
    property bool vertical: false
    property int barSize: 30
    property bool transparent: false
    property bool foregroundAnimationEnabled: false
    property color barForeground: "white"
    property var activePopout: null
    property bool centerHoverRevealSuppressed: false
    function registerClickTarget(target) {}
    function unregisterClickTarget(target) {}
    function showTooltip(target, text) {}
    function hideTooltip(target) {}
    function requestPopout(owner) {activePopout = owner}
    function releasePopout(owner) {activePopout = null}
    function targetBelongsToWindow(target, window) {return true}
  }
  QtObject {
    id: registry
    property var widgets: ({})
    function metadataFor(id) {return null}
  }
  Monitor.Bar {
    id: integratedBar
    shell: hostShell
    barWidgetRegistry: registry
    barConfig: hostShell.barConfig
    omarchyPath: "/usr/share/omarchy"
  }
  Groups.Service { id: service; shell: hostShell; hostBar: hostBar }
  Groups.ManagerWidget { id: manager; bar: hostBar }
  Groups.GroupButton {bar: hostBar; settings: ({shelfishGroupId: "default"})}
  Groups.SettingsButton {bar: hostBar}
  Timer {
    interval: 500; running: true
    onTriggered: {
      if (!service.createGroup("Smoke")) throw new Error("save failed")
      if (service.config.groups.length !== 2) throw new Error("group missing")
      if (!service.setWidget("smoke", "test.widget", true)) throw new Error("membership failed")
      if (!service.restoreAll()) throw new Error("restore failed")
      var full = integratedBar.fullLayout("smoke")
      var managerEntry = full.right.find(function(entry) {return entry.id === "patrickfanella.monitor-bar.groups"})
      if (!managerEntry || managerEntry.source.indexOf("groups/ManagerWidget.qml") < 0) throw new Error("integrated manager missing")
      console.log("GROUP_SMOKE_PASSED")
      Qt.quit()
    }
  }
}
