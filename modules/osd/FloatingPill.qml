pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.effects
import qs.services

// The notch OSD over a fullscreen window: the border is hidden, so it floats as a pill at the top centre
// on its own overlay surface. Click-through and never focused; state, timer and spring come from the Wrapper.
StyledWindow {
    id: root

    required property Wrapper osd

    readonly property int gap: contentItem.Tokens.padding.medium

    name: "osd-fullscreen"
    visible: osd.floating && osd.drop > 0
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}
    anchors.top: true

    // Fixed size with room for the overshoot and shadow, so the surface isn't resized every frame
    implicitWidth: osd.notchWidth + 120
    implicitHeight: osd.notchHeight + 60 + gap

    Elevation {
        anchors.fill: pill
        radius: pill.radius
        level: 2
        opacity: root.osd.presence
    }

    StyledRect {
        id: pill

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.gap
        width: root.osd.shapeWidth
        height: root.osd.shapeHeight
        radius: Math.min(height, root.osd.notchHeight) / 2
        color: Colours.tPalette.m3surface
        clip: true

        Loader {
            anchors.centerIn: parent

            active: root.visible
            opacity: Math.max(0, root.osd.presence * 2 - 1)

            sourceComponent: Content {
                width: root.osd.notchWidth
                height: root.osd.notchHeight
                kind: root.osd.kind
                volume: root.osd.volume
                muted: root.osd.muted
                sourceVolume: root.osd.sourceVolume
                sourceMuted: root.osd.sourceMuted
                brightness: root.osd.brightness
            }
        }
    }
}
