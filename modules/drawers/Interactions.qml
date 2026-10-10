import QtQuick
import QtQuick.Controls
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.modules.bar as Bar
import qs.modules.bar.popouts as BarPopouts

CustomMouseArea {
    id: root

    required property ShellScreen screen
    required property BarPopouts.Wrapper popouts
    required property ScreenState screenState
    required property Panels panels
    required property Bar.BarWrapper bar
    required property TopBar topBar
    required property real borderThickness
    required property real topThickness
    required property bool fullscreen

    property point dragStart
    property bool dashboardShortcutActive
    property bool notchShortcutActive
    property bool utilitiesShortcutActive

    function withinPanelHeight(panel: Item, x: real, y: real): bool {
        const panelY = root.topThickness + panel.y;
        return y >= panelY - Config.border.rounding && y <= panelY + panel.height + Config.border.rounding;
    }

    function withinPanelWidth(panel: Item, x: real, y: real): bool {
        const panelX = bar.implicitWidth + panel.x;
        return x >= panelX - Config.border.rounding && x <= panelX + panel.width + Config.border.rounding;
    }

    function inLeftPanel(panel: Item, x: real, y: real): bool {
        return x < bar.implicitWidth + panel.x + panel.width && withinPanelHeight(panel, x, y);
    }

    function inRightPanel(panel: Item, x: real, y: real): bool {
        return x > Math.min(width - Config.border.minThickness, bar.implicitWidth + panel.x) && withinPanelHeight(panel, x, y);
    }

    function inPopout(x: real, y: real): bool {
        const panel = panels.popoutsWrapper;
        return y < root.topThickness + panel.y + panel.height + Config.border.rounding && withinPanelWidth(panel, x, y);
    }

    function inTopPanel(panel: Item, x: real, y: real): bool {
        const panelHeight = panel.height * (1 - (panel.offsetScale ?? 0)); // qmllint disable missing-property
        return y < Math.max(Config.border.minThickness, root.topThickness + panelHeight) && withinPanelWidth(panel, x, y);
    }

    // The dashboard panel itself, or the top border strip above it (the hover trigger, as wide as the full window)
    function inDashboard(x: real, y: real): bool {
        const panel = panels.dashboard;
        const centre = bar.implicitWidth + panel.x + panel.width / 2;
        const inTrigger = y < Math.max(Config.border.minThickness, root.topThickness) && Math.abs(x - centre) <= panel.reservedWidth / 2 + Config.border.rounding;
        return inTrigger || inTopPanel(panel, x, y);
    }

    function inBottomPanel(panel: Item, x: real, y: real, isCorner = false): bool {
        const panelHeight = panel.height * (1 - (panel.offsetScale ?? 0)); // qmllint disable missing-property
        return y > height - Math.max(Config.border.minThickness, Config.border.thickness + panelHeight) - (isCorner ? Config.border.rounding : 0) && withinPanelWidth(panel, x, y);
    }

    function onWheel(event: WheelEvent): void {
        if (fullscreen)
            return;
        if (event.x < bar.implicitWidth) {
            bar.handleWheel(event.y, event.angleDelta);
        }
    }

    anchors.fill: parent
    acceptedButtons: fullscreen ? Qt.NoButton : Qt.AllButtons
    hoverEnabled: true

    onPressed: event => dragStart = Qt.point(event.x, event.y)
    onContainsMouseChanged: {
        if (!containsMouse) {
            if (!dashboardShortcutActive)
                screenState.dashboard = false;

            if (!notchShortcutActive)
                screenState.dashboardNotch = false;

            if (!utilitiesShortcutActive)
                screenState.utilities = false;

            // Deferred, so moving onto the top border icons (which take the hover) keeps their popout open
            Qt.callLater(() => {
                if (!containsMouse && !topBar.hovered && (!popouts.currentName.startsWith("traymenu") || ((popouts.current as StackView)?.depth ?? 0) <= 1)) {
                    popouts.hasCurrent = false;
                    bar.closeTray();
                }
            });

            if (Config.bar.showOnHover)
                bar.isHovered = false;

            if (Config.sidebar.showOnHover)
                screenState.sidebar = false;
        }
    }

    onPositionChanged: event => {
        if (popouts.isDetached)
            return;

        const x = event.x;
        const y = event.y;
        const dragX = x - dragStart.x;
        const dragY = y - dragStart.y;

        if (fullscreen)
            return;

        // Show bar in non-exclusive mode on hover
        if (!screenState.bar && Config.bar.showOnHover && x < bar.clampedWidth)
            bar.isHovered = true;

        // Show/hide bar on drag
        if (pressed && dragStart.x < bar.clampedWidth) {
            if (dragX > Config.bar.dragThreshold)
                screenState.bar = true;
            else if (dragX < -Config.bar.dragThreshold)
                screenState.bar = false;
        }

        if (panels.sidebar.offsetScale === 1) {
            const showSidebar = pressed && dragStart.x > Math.min(width - Config.border.minThickness, bar.implicitWidth + panels.sidebar.x);

            // Show sidebar on hover (top-right corner, bounded by notification panel height)
            if (Config.sidebar.showOnHover) {
                const sidebarTriggerY = Math.max(Config.sidebar.minHoverThreshold, panels.notifications.y + panels.notifications.height + topThickness);
                const showSidebarHover = x > Math.min(width - Config.border.minThickness, bar.implicitWidth + panels.sidebar.x) && y <= sidebarTriggerY;
                if (showSidebarHover && !screenState.sidebar)
                    screenState.sidebar = true;
            }

            // Show/hide session on drag
            if (pressed && inRightPanel(panels.sessionWrapper, dragStart.x, dragStart.y) && withinPanelHeight(panels.sessionWrapper, x, y)) {
                if (dragX < -Config.session.dragThreshold)
                    screenState.session = true;
                else if (dragX > Config.session.dragThreshold)
                    screenState.session = false;

                // Show sidebar on drag if in session area and session is nearly fully visible
                if (showSidebar && panels.session.offsetScale <= 0 && dragX < -Config.sidebar.dragThreshold)
                    screenState.sidebar = true;
            } else if (showSidebar && dragX < -Config.sidebar.dragThreshold) {
                // Show sidebar on drag if not in session area
                screenState.sidebar = true;
            }
        } else {
            const outOfSidebar = x < width - panels.sidebar.width * (1 - panels.sidebar.offsetScale);
            // Show/hide session on drag
            if (pressed && outOfSidebar && inRightPanel(panels.sessionWrapper, dragStart.x, dragStart.y) && withinPanelHeight(panels.sessionWrapper, x, y)) {
                if (dragX < -Config.session.dragThreshold)
                    screenState.session = true;
                else if (dragX > Config.session.dragThreshold)
                    screenState.session = false;
            }

            // Show/hide sidebar on hover
            if (Config.sidebar.showOnHover && !pressed) {
                const sidebarTriggerY = Math.max(Config.sidebar.minHoverThreshold, panels.notifications.y + panels.notifications.height + topThickness);
                const showSidebarHover = x > Math.min(width - Config.border.minThickness, bar.implicitWidth + panels.sidebar.x) && y <= sidebarTriggerY;
                if (showSidebarHover && !screenState.sidebar) {
                    screenState.sidebar = true;
                } else {
                    const inSidebarArea = inRightPanel(panels.sidebar, x, y) || inRightPanel(panels.sessionWrapper, x, y);
                    if (!inSidebarArea)
                        screenState.sidebar = false;
                }
            }

            // Hide sidebar on drag
            if (pressed && inRightPanel(panels.sidebar, dragStart.x, 0) && dragX > Config.sidebar.dragThreshold)
                screenState.sidebar = false;
        }

        // Show launcher on hover, or show/hide on drag if hover is disabled
        if (Config.launcher.showOnHover) {
            if (!screenState.launcher && inBottomPanel(panels.launcher, x, y))
                screenState.launcher = true;
        } else if (pressed && inBottomPanel(panels.launcher, dragStart.x, dragStart.y) && withinPanelWidth(panels.launcher, x, y)) {
            if (dragY < -Config.launcher.dragThreshold)
                screenState.launcher = true;
            else if (dragY > Config.launcher.dragThreshold)
                screenState.launcher = false;
        }

        // Hovering the top centre drops the small notch; the full window (opened from it) closes once left
        const showDashboard = Config.dashboard.showOnHover && inDashboard(x, y);

        if (screenState.dashboard) {
            if (!dashboardShortcutActive)
                screenState.dashboard = showDashboard;
            else if (showDashboard)
                // If hovering over dashboard area while in shortcut mode, transition to hover control
                dashboardShortcutActive = false;
        } else if (!notchShortcutActive) {
            screenState.dashboardNotch = showDashboard;
        } else if (showDashboard) {
            notchShortcutActive = false;
        }

        // Show/hide the notch on drag (for touchscreen devices)
        if (pressed && inTopPanel(panels.dashboard, dragStart.x, dragStart.y) && withinPanelWidth(panels.dashboard, x, y)) {
            if (dragY > Config.dashboard.dragThreshold && !screenState.dashboard) {
                screenState.dashboardNotch = true;
            } else if (dragY < -Config.dashboard.dragThreshold) {
                screenState.dashboard = false;
                screenState.dashboardNotch = false;
            }
        }

        // Show utilities on hover
        const showUtilities = inBottomPanel(panels.utilities, x, y, true);

        // Always update visibility based on hover if not in shortcut mode
        if (!utilitiesShortcutActive) {
            screenState.utilities = showUtilities;
        } else if (showUtilities) {
            // If hovering over utilities area while in shortcut mode, transition to hover control
            utilitiesShortcutActive = false;
        }

        // Hide popouts once the cursor leaves both the top border icons (TopBar opens popouts from
        // its own hover handlers) and the popout hanging below them
        const overTopBar = y < topThickness && x >= topBar.x && x <= topBar.x + topBar.width;
        if (!overTopBar && (!popouts.currentName.startsWith("traymenu") || ((popouts.current as StackView)?.depth ?? 0) <= 1) && !inPopout(x, y)) {
            popouts.hasCurrent = false;
            bar.closeTray();
        }
    }

    // Monitor individual visibility changes
    Connections {
        function onLauncherChanged() {
            // If launcher is hidden, clear shortcut flags for dashboard and utilities
            if (!root.screenState.launcher) {
                root.dashboardShortcutActive = false;
                root.notchShortcutActive = false;
                root.utilitiesShortcutActive = false;

                // Also hide dashboard if it's not being hovered
                const inDashboardArea = root.inDashboard(root.mouseX, root.mouseY);

                if (!inDashboardArea) {
                    root.screenState.dashboard = false;
                    root.screenState.dashboardNotch = false;
                }
            }
        }

        function onDashboardChanged() {
            if (root.screenState.dashboard) {
                // Dashboard became visible, immediately check if this should be shortcut mode.
                // Opened from the notch counts as hovered (the pointer is on its button)
                if (!root.screenState.dashboardNotch && !(root.containsMouse && root.inDashboard(root.mouseX, root.mouseY))) {
                    root.dashboardShortcutActive = true;
                }
            } else {
                // Dashboard hidden, clear shortcut flag
                root.dashboardShortcutActive = false;
            }
        }

        function onDashboardNotchChanged() {
            if (root.screenState.dashboardNotch) {
                // Notch opened by a keybind stays until hovered and left, or toggled again
                if (!(root.containsMouse && root.inDashboard(root.mouseX, root.mouseY)))
                    root.notchShortcutActive = true;
            } else {
                root.notchShortcutActive = false;
            }
        }

        function onUtilitiesChanged() {
            if (root.screenState.utilities) {
                // Utilities became visible, immediately check if this should be shortcut mode
                const inUtilitiesArea = root.inBottomPanel(root.panels.utilities, root.mouseX, root.mouseY);
                if (!inUtilitiesArea) {
                    root.utilitiesShortcutActive = true;
                }
            } else {
                // Utilities hidden, clear shortcut flag
                root.utilitiesShortcutActive = false;
            }
        }

        target: root.screenState
    }
}
