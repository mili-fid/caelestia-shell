pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.I18n
import qs.components

// The dashboard as one shape hanging from the top border (its background is dashBg, a blob in the drawers window).
// Hovering drops a small notch: a row of live tiles, one per tab (screenState.dashboardNotch). Picking a tile grows
// the same shape into the full window (screenState.dashboard); the tile row stays on top as its tab strip and the
// tab's page rises in underneath. Size and drop run on springs, so the shape overshoots a touch and settles.
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

    readonly property bool fullOpen: screenState.dashboard && Config.dashboard.enabled
    readonly property bool notchOpen: screenState.dashboardNotch && Config.dashboard.enabled && !fullOpen
    readonly property bool shouldBeActive: fullOpen || notchOpen

    // How far the shape has dropped out of the border, on a spring: past 1 while it overshoots on the way in.
    // Set in update(), so a new hover can reset it to closed before it drops again
    property real drop
    readonly property real presence: Math.max(0, Math.min(1, drop))
    readonly property real stretch: Math.max(0, drop - 1) // The overshoot, spent stretching the shape like jelly
    // 0 = shown, 1 = hidden in the border (what the drawers' hover/mask logic expects)
    readonly property real offsetScale: 1 - presence

    // 0 = small notch, 1 = full window. Closing keeps the current shape; once closed (or if a hover interrupts the
    // close) everything resets to a fresh small notch, so a new hover never shows the full window
    property bool fullMode
    property bool resetting // True only inside resetToNotch(): no animations, header and page unloaded
    property bool opening // Whether drop is heading out (springy) or back in (quick); set with it in update()
    property real morph: fullMode ? 1 : 0
    readonly property real clampedMorph: Math.max(0, Math.min(1, morph))
    // Like offsetScale, but only for the full window (1 while just the notch is out). Drives the timer pill flight
    readonly property real fullOffsetScale: 1 - presence * clampedMorph
    // Room kept free at the top centre (hover trigger, top border widgets), independent of the current shape
    readonly property real reservedWidth: Math.max(854, width)

    readonly property int notchPadding: 8
    readonly property int fullPadding: Tokens.padding.large
    readonly property real padding: notchPadding + (fullPadding - notchPadding) * clampedMorph
    readonly property int notchWidth: 3 * 226 + 2 * 6 + notchPadding * 2
    readonly property real notchHeight: header.implicitHeaderHeight + notchPadding * 2
    // Pages build asynchronously, so until one is ready its size from last time stands in (the springs then
    // retarget smoothly if it changed)
    property var pageSizes: ({})
    readonly property size pageSize: {
        const w = content.item?.implicitWidth ?? 0;
        const h = content.item?.implicitHeight ?? 0;
        const known = pageSizes[screenState.dashboardTab];
        return w > 0 && h > 0 ? Qt.size(w, h) : known ?? Qt.size(840, Tokens.sizes.dashboard.mediaTabHeight);
    }
    readonly property real fullWidth: pageSize.width + fullPadding * 2
    readonly property real fullHeight: notchPadding + header.implicitHeaderHeight + Tokens.spacing.medium + fullPadding + pageSize.height

    // Target size; the springs below chase it. Width leads and height follows, so the growth feels elastic
    property real shapeWidth: fullMode ? fullWidth : notchWidth
    property real shapeHeight: fullMode ? fullHeight : notchHeight

    function pick(index: int): void {
        screenState.dashboardTab = index;
        if (fullOpen)
            return;
        // Open the full window before closing the notch, so the hover logic knows it came from here
        screenState.dashboard = true;
        screenState.dashboardNotch = false;
    }

    onPageSizeChanged: {
        if (content.item?.implicitWidth > 0 && content.item?.implicitHeight > 0)
            pageSizes[screenState.dashboardTab] = pageSize;
    }
    // Runs from the change handlers, where the derived properties above may not have updated yet, so it works
    // from screenState directly
    function update(): void {
        const enabled = Config.dashboard.enabled;
        const full = screenState.dashboard && enabled;
        const notch = screenState.dashboardNotch && enabled && !full;
        if (full) {
            fullMode = true;
        } else if (notch && fullMode) {
            // A hover while the full window is still closing: start over from a clean notch, never from the window
            resetToNotch();
        }
        opening = full || notch;
        drop = opening ? 1 : 0;
    }

    // Snaps to closed, small notch, nothing selected: size, morph and drop jump without animating, and the header
    // and page are recreated from scratch. The last chosen tab stays in screenState for the next pick
    function resetToNotch(): void {
        if (resetting)
            return;
        resetting = true;
        fullMode = false;
        drop = 0;
        resetting = false;
    }

    onFullOpenChanged: update()
    onNotchOpenChanged: update()
    onVisibleChanged: {
        if (!visible)
            resetToNotch();
    }

    visible: drop > 0
    clip: true
    // Grows out of the border's edge (never slides through the border row), widening as it lands; the overshoot
    // stretches it a little
    implicitWidth: shapeWidth * (0.6 + 0.4 * presence) + stretch * 120
    implicitHeight: shapeHeight * presence + stretch * 60

    Behavior on drop {
        enabled: !root.resetting

        SpringAnimation {
            // Springy on the way in, quick and settled on the way out
            spring: root.opening ? 3.2 : 5
            damping: root.opening ? 0.26 : 0.55
            epsilon: 0.002
        }
    }

    Behavior on morph {
        enabled: root.visible && !root.resetting

        SpringAnimation {
            spring: 3.4
            damping: 0.34
            epsilon: 0.002
        }
    }

    Behavior on shapeWidth {
        enabled: root.visible && !root.resetting

        SpringAnimation {
            spring: 3.6
            damping: 0.3
            epsilon: 0.25
        }
    }

    Behavior on shapeHeight {
        enabled: root.visible && !root.resetting

        SpringAnimation {
            spring: 3
            damping: 0.32
            epsilon: 0.25
        }
    }

    // Only exists while out, so its live data (CPU/RAM polling, notes file watch) stops when closed
    Loader {
        id: header

        readonly property real implicitHeaderHeight: 52 // NotchMenu.tileHeight, known before it loads

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.padding
        anchors.topMargin: root.notchPadding

        z: 1
        active: (root.shouldBeActive || root.visible) && !root.resetting
        opacity: Math.min(1, root.presence * 1.6)

        sourceComponent: NotchMenu {
            screenState: root.screenState
            tabs: root.tabInfo
            expanded: root.clampedMorph
            presence: root.presence

            onPicked: index => root.pick(index)
        }
    }

    // The tab's page, rising in under the tile row as the shape grows
    Loader {
        id: content

        readonly property real reveal: {
            const t = Math.max(0, Math.min(1, (root.morph - 0.3) / 0.6));
            return t * t * (3 - 2 * t);
        }

        anchors.horizontalCenter: parent.horizontalCenter
        y: header.y + header.implicitHeaderHeight + Tokens.spacing.medium - (1 - reveal) * 24

        // Not loaded behind the small notch (its pages poll); created when a tile is picked
        active: root.fullMode && (root.shouldBeActive || root.visible) && !root.resetting
        visible: reveal > 0
        enabled: root.fullOpen
        opacity: reveal * Math.min(1, root.presence * 1.4)
        scale: 0.96 + 0.04 * reveal

        sourceComponent: Content {
            screenState: root.screenState
            tabInfo: root.tabInfo
            animate: root.fullOpen && root.clampedMorph > 0.9
        }
    }
}
