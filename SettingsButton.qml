// SPDX-License-Identifier: MIT

import QtQuick
import qs.Commons
import qs.Ui
import "I18n.js" as I18n

WidgetButton {
  id: root

  property string moduleName: ""
  property var settings: ({})
  property string screenName: ""
  readonly property string locale: I18n.currentLocale()

  text: "󰒓"
  fontFamily: Style.font.family
  fontSize: Style.font.icon
  tooltipText: I18n.t(locale, "settings.title")
  Accessible.role: Accessible.Button
  Accessible.name: I18n.t(locale, "settingsButton.open")
  Accessible.description: I18n.t(locale, "settingsButton.description")
  Accessible.onPressAction: root.activate()
  activeFocusOnTab: true

  function activate() {
    if (bar && bar.shell && typeof bar.shell.summon === "function")
      bar.shell.summon("patrickfanella.monitor-bar", "{}")
  }

  Keys.onPressed: function(event) {
    if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return
    if (!event.isAutoRepeat) root.activate()
    event.accepted = true
  }

  Rectangle {
    anchors.fill: parent
    z: 2
    visible: root.activeFocus
    color: "transparent"
    border.color: Color.accent
    border.width: Style.normalBorderWidth
    radius: Style.cornerRadius
  }

  onPressed: function(button) {
    if (button === Qt.LeftButton) root.activate()
  }
}
