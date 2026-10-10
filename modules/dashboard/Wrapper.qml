pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.I18n
import qs.components

// Hover opens a small notch with a button per tab (screenState.dashboardNotch). Picking one morphs the
// notch into the full dashboard on that tab (screenState.dashboard).
Item {
    id: root

    required property ScreenState screenState

    readonly property var tabInfo: [
        {
            iconName: "speed",
            text: Tr.tr("Performance")
        },
        {
            iconName: "timer",
            text: Tr.tr("Timer")
        },
        {
            iconName: "edit_note",
            text: Tr.tr("Notes")
        }
    ]

    readonly property real nonAnimHeight: (content.item as Content)?.nonAnimHeight ?? 0
    readonly property bool fullOpen: screenState.dashboard && Config.dashboard.enabled
    readonly property bool notchOpen: screenState.dashboardNotch && Config.dashboard.enabled && !fullOpen
    readonly property bool shouldBeActive: fullOpen || notchOpen
    property real offsetScale: shouldBeActive ? 0 : 1

    // 0 = small notch, 1 = full dashboard. Closing keeps the current shape, so the full window
    // slides away as before; it only snaps back to the notch shape while hidden
    property real morph
    readonly property real clampedMorph: Math.max(0, Math.min(1, morph)) // The spring overshoots
    // Like offsetScale, but only for the full window (1 while just the notch is out). Drives the timer pill flight
    readonly property real fullOffsetScale: 1 - (1 - Math.max(0, Math.min(1, offsetScale))) * clampedMorph
    // Room kept free at the top centre (hover trigger, top border widgets), independent of the current shape
    readonly property real reservedWidth: Math.max(854, width)

    readonly property real notchWidth: notchMenu.implicitWidth * (1 - 0.45 * Math.max(0, offsetScale)) // Grows outwards as it drops
    readonly property real fullWidth: content.item?.implicitWidth || 854 // Hard coded fallback for first open
    readonly property real fullHeight: content.item?.implicitHeight ?? 0

    onFullOpenChanged: {
        if (fullOpen)
            morph = 1;
    }
    onNotchOpenChanged: {
        if (notchOpen)
            morph = 0;
    }

    visible: offsetScale < 1
    clip: true
    anchors.topMargin: (-implicitHeight - 5) * offsetScale
    implicitWidth: notchWidth + (fullWidth - notchWidth) * morph
    implicitHeight: notchMenu.implicitHeight + (fullHeight - notchMenu.implicitHeight) * morph
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {
            // The notch is quick and springy; the full window keeps the usual drawer animation
            type: root.morph > 0.5 ? Anim.DefaultSpatial : root.shouldBeActive ? Anim.FastSpatial : Anim.Emphasized
            duration: root.morph > 0.5 ? Tokens.anim.durations.expressiveDefaultSpatial : 240
        }
    }

    Behavior on morph {
        enabled: root.visible

        Anim {
            type: Anim.FastSpatial
            duration: 280
        }
    }

    Loader {
        id: content

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        // Also loaded behind the notch, so the morph knows the full size straight away
        active: root.shouldBeActive || root.visible
        visible: root.morph > 0
        enabled: root.fullOpen
        opacity: Math.max(0, Math.min(1, (root.morph - 0.3) / 0.6))

        sourceComponent: Content {
            screenState: root.screenState
            tabInfo: root.tabInfo
            animate: root.fullOpen && root.clampedMorph === 1
        }
    }

    NotchMenu {
        id: notchMenu

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        tabs: root.tabInfo
        visible: opacity > 0
        enabled: root.notchOpen
        opacity: Math.max(0, Math.min(1, 1 - root.morph * 3))

        onPicked: index => {
            root.screenState.dashboardTab = index;
            // Open the full window before closing the notch, so the hover logic knows it came from here
            root.screenState.dashboard = true;
            root.screenState.dashboardNotch = false;
        }
    }
}
