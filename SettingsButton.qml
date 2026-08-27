// SPDX-License-Identifier: MIT

import QtQuick
import qs.Commons
import qs.Ui

WidgetButton {
  id: root

  property string moduleName: ""
  property var settings: ({})
  property string screenName: ""

  text: "󰒓"
  fontFamily: Style.font.family
  fontSize: Style.font.icon
  tooltipText: "Monitor bar settings"
  Accessible.role: Accessible.Button
  Accessible.name: "Open monitor bar settings"
  Accessible.description: "Opens monitor bar settings in a separate keyboard-focusable window"
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
