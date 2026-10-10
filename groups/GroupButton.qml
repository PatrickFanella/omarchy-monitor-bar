import QtQuick
import qs.Ui
import "I18n.js" as I18n
import "SharedService.js" as SharedService

BarWidget {
  id: root

  readonly property var hostBar: root.bar
  readonly property string groupId: {
    if (settings && settings.shelfishGroupId) return String(settings.shelfishGroupId)
    if (root.moduleName && root.moduleName.indexOf("patrickfanella.monitor-bar.groups.group.") === 0) {
      return root.moduleName.slice("patrickfanella.monitor-bar.groups.group.".length)
    }
    return ""
  }
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
  readonly property var group: {
    if (!service || !service.config || !service.config.groups) return null
    for (var i = 0; i < service.config.groups.length; i++)
      if (service.config.groups[i].id === groupId) return service.config.groups[i]
    return null
  }
  readonly property bool opened: {
    if (!service || !groupId) return false
    var active = service.revealedGroupId || service.activeGroupId || (service.config ? service.config.activeGroupId : "") || ""
    return active === groupId
  }

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
    text: root.group ? root.group.icon : "\uf07b"
    active: root.opened
    tooltipText: root.group ? root.group.name : root.tr("group.fallback")
    onPressed: function(mouseButton) {
      if (!root.service) root.service = root.findService()
      if (mouseButton === Qt.RightButton && root.service) root.service.manage()
      else if (mouseButton === Qt.MiddleButton && root.service) root.service.hide()
      else if (root.service && root.service.canToggleGroups()) root.service.toggleGroup(root.groupId)
    }
  }
}
