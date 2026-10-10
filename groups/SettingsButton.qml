import QtQuick
import qs.Ui
import "I18n.js" as I18n
import "SharedService.js" as SharedService

BarWidget {
  id: root

  readonly property var hostBar: root.bar
  function getSlots() {
    if (root.bar && root.bar.moduleSlots && root.bar.moduleSlots.length > 0) {
      return root.bar.moduleSlots
    }
    var p = root.parent
    while (p) {
      if (p.moduleSlots && p.moduleSlots.length > 0) return p.moduleSlots
      if (p.children && p.children.length > 0) {
        var slots = []
        for (var i = 0; i < p.children.length; i++) {
          var c = p.children[i]
          if (c && c.moduleName !== undefined && "activeItem" in c) slots.push(c)
        }
        if (slots.length > 0) return slots
      }
      p = p.parent
    }
    return []
  }

  function findService() {
    var s = SharedService.getService()
    if (s) return s
    if (bar && bar.shell && typeof bar.shell.serviceFor === "function") {
      s = bar.shell.serviceFor("patrickfanella.monitor-bar.groups")
      if (s) return s
    }
    return null
  }
  property var service: findService()

  function tr(key) { return service && typeof service.tr === "function" ? service.tr(key) : I18n.translate(Qt.locale().name, key) }

  function syncHost() {
    if (!service) {
      var s = findService()
      if (s) service = s
    }
    if (service && typeof service.registerPanelHost === "function") {
      service.registerPanelHost(root)
    }
  }

  onParentChanged: syncHost()
  Component.onCompleted: {
    if (!service) {
      SharedService.onServiceAvailable(function(s) {
        root.service = s
        root.syncHost()
      })
    }
    syncHost()
  }
  Component.onDestruction: {
    if (service && typeof service.unregisterPanelHost === "function") {
      service.unregisterPanelHost(root)
    }
  }
  onServiceChanged: syncHost()

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf1de"
    tooltipText: root.tr("settings.shortcut")
    onPressed: function(mouseButton) {
      if (!root.service) root.service = root.findService()
      if (!root.service) return
      if (mouseButton === Qt.MiddleButton) root.service.hide()
      else root.service.manage()
    }
  }
}
