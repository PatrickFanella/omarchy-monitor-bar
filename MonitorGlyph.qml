// SPDX-License-Identifier: MIT

import QtQuick
import qs.Commons
import qs.Ui

// A visual monitor marker only. It deliberately has no MouseArea, tooltip, or
// bar registration, so it cannot become an accidental action target.
Item {
    id: root

    property var bar: null
    property string moduleName: ""
    property var settings: ({
    })
    readonly property string glyph: settings && settings.glyph !== undefined ? String(settings.glyph) : ""
    // Optional display-only name shown after the glyph, in the theme accent.
    readonly property string label: settings && settings.label !== undefined ? String(settings.label) : ""
    readonly property bool showLabel: label !== "" && !vertical
    readonly property real glyphRotation: settings && settings.rotation !== undefined ? Number(settings.rotation) : 0
    readonly property string accessibleLabel: settings && settings.accessibleLabel !== undefined ? String(settings.accessibleLabel) : ""
    readonly property bool vertical: bar ? bar.vertical : false
    readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal
    // Keep the planet symbols on a known Unicode symbol face. Qt still falls
    // back normally if a local font build does not contain either glyph.
    readonly property string fontFamily: "Noto Sans Symbols 2"
    readonly property color foreground: bar ? bar.barForeground : Color.bar.text

    implicitWidth: vertical ? barSize : Style.bar.iconSlot + (showLabel ? labelText.implicitWidth + Style.space(8) : 0)
    implicitHeight: vertical ? Style.bar.iconSlot : barSize
    // This is an orientation cue, not a control. The workspace buttons beside
    // it provide the actionable semantics for the monitor's bar.
    Accessible.ignored: true
    Accessible.name: root.accessibleLabel

    OpticalGlyph {
        id: glyphItem
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: root.showLabel ? undefined : parent.horizontalCenter
        x: root.showLabel ? (Style.bar.iconSlot - width) / 2 : 0
        width: Style.bar.iconCanvas
        height: Style.bar.iconCanvas
        text: root.glyph
        fontFamily: root.fontFamily
        fontSize: Style.bar.iconFont
        color: root.foreground
        rotation: root.glyphRotation
    }

    Text {
        id: labelText
        visible: root.showLabel
        anchors.verticalCenter: parent.verticalCenter
        x: Style.bar.iconSlot
        text: root.label
        color: Color.accent
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 1
    }

}
