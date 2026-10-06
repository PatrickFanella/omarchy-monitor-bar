// SPDX-License-Identifier: MIT
import QtQuick
import QtTest
import ".."

TestCase {
  id: testCase
  name: "PopupCompatibility"
  property bool hostSuppressed: false
  property int calls: 0
  property bool panelOpen: true

  MonitorPluginBarApi {
    id: api
    pluginId: "test.popup"
    moduleName: "test.popup"
    _centerHoverRevealSuppressed: testCase.hostSuppressed
    _setCenterHoverRevealSuppressed: function(value) {
      calls++
      hostSuppressed = value
    }
  }

  function init() {
    hostSuppressed = false
    panelOpen = true
    calls = 0
  }

  function test_legacy_close_completes() {
    api.centerHoverRevealSuppressed = true
    compare(hostSuppressed, true)
    // Legacy panels clear suppression before hiding their controller.
    api.centerHoverRevealSuppressed = false
    panelOpen = false
    compare(panelOpen, false)
    compare(hostSuppressed, false)
    compare(calls, 2)
  }

  function test_host_updates_after_legacy_write() {
    api.centerHoverRevealSuppressed = true
    hostSuppressed = false
    compare(api.centerHoverRevealSuppressed, false)
    hostSuppressed = true
    compare(api.centerHoverRevealSuppressed, true)
    compare(calls, 1)
  }

  function test_supported_setter() {
    api.setCenterHoverRevealSuppressed(true)
    compare(api.centerHoverRevealSuppressed, true)
    compare(calls, 1)
  }
}
