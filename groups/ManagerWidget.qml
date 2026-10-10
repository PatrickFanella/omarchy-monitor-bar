import QtQuick
import qs.Ui
import "I18n.js" as I18n
import "SharedService.js" as SharedService

BarWidget {
  id: root

  moduleName: "patrickfanella.monitor-bar.groups"
  property bool managerOpen: false
  property var registeredService: null
  readonly property bool opened: managerOpen
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

  readonly property var service: {
    var s = SharedService.getService()
    if (s) return s
    if (bar && bar.shell && typeof bar.shell.serviceFor === "function") {
      return bar.shell.serviceFor(moduleName)
    }
    return null
  }

  function tr(key) { return service && typeof service.tr === "function" ? service.tr(key) : I18n.translate(Qt.locale().name, key) }

  function syncRegistration() {
    if (registeredService === service) {
      if (service && typeof service.reconcileSlots === "function") service.reconcileSlots()
      return
    }
    if (registeredService) registeredService.unregisterPanelHost(root)
    registeredService = service
    if (registeredService) {
      registeredService.registerPanelHost(root)
      if (typeof registeredService.reconcileSlots === "function") registeredService.reconcileSlots()
    }
  }
  function openManager() {
    if (service) {
      service.suppressStatusReveal()
      service.hide()
    }
    managerOpen = true
  }
  function open() { openManager() }
  function close() {
    if (service) {
      service.suppressStatusReveal()
      service.suppressGroupToggles()
      service.hide()
    }
    managerOpen = false
  }

  implicitWidth: managerButton.implicitWidth
  implicitHeight: managerButton.implicitHeight

  onParentChanged: syncRegistration()
  Component.onCompleted: syncRegistration()
  Component.onDestruction: if (registeredService) registeredService.unregisterPanelHost(root)
  onServiceChanged: syncRegistration()

  BarIconButton {
    id: managerButton
    anchors.fill: parent
    bar: root.bar
    text: "\uf1de"
    active: root.managerOpen
    tooltipText: root.tr("settings.shortcut")
    onPressed: root.managerOpen ? root.close() : root.openManager()
  }

  ManagePanel {
    anchorItem: managerButton
    owner: root
    bar: root.bar
    service: root.service
    open: root.managerOpen
    onOpenChanged: if (!open && root.managerOpen) root.close()
  }
}
