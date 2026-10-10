pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components

Item {
    id: root

    required property ScreenState screenState

    // Icons and labels come from the wrapper, which shares them with the small notch
    required property var tabInfo
    // Off while morphing out of the notch (or opening from the timer pill), so the picked tab just appears
    property bool animate: true
    readonly property var dashboardTabs: {
        const components = [performanceComponent, timerComponent, notesComponent];
        return tabInfo.map((tab, i) => Object.assign({
                component: components[i]
            }, tab));
    }

    // The page on screen: the chosen tab once it has loaded. Until then the previous one stays, so there's never a gap
    property int shownIndex: -1
    readonly property Loader currentPage: {
        pages.count; // Trigger update on count change
        return pages.itemAt(screenState.dashboardTab) as Loader;
    }
    readonly property Loader shownPage: {
        pages.count;
        return pages.itemAt(shownIndex) as Loader;
    }

    // The first page to appear (opening from the notch or the timer pill) just shows; only later switches animate
    property bool hasShown

    onShownIndexChanged: {
        if (shownIndex >= 0 && !hasShown)
            Qt.callLater(() => hasShown = true);
    }

    function switchBy(delta: int): void {
        screenState.dashboardTab = Math.max(0, Math.min(tabInfo.length - 1, screenState.dashboardTab + delta));
    }

    implicitWidth: shownPage?.implicitWidth ?? 0
    implicitHeight: shownPage?.implicitHeight ?? 0

    // Pages build asynchronously; show the chosen one as soon as it's ready
    Binding on shownIndex {
        when: root.currentPage?.status === Loader.Ready
        value: root.screenState.dashboardTab
        restoreMode: Binding.RestoreNone
    }

    // Horizontal swipes (touchpad, or dragging the page) switch straight to the neighbouring tab
    property real swipe

    WheelHandler {
        orientation: Qt.Horizontal
        acceptedDevices: PointerDevice.TouchPad
        onWheel: event => {
            root.swipe += event.angleDelta.x;
            if (Math.abs(root.swipe) > 240) {
                root.switchBy(root.swipe < 0 ? 1 : -1);
                root.swipe = 0;
            }
        }
        onActiveChanged: root.swipe = 0
    }

    DragHandler {
        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        onActiveChanged: {
            if (!active && Math.abs(translation.x) > 80)
                root.switchBy(translation.x < 0 ? 1 : -1);
        }
    }

    // The tab strip is the notch's tile row (NotchMenu), which stays on top of this in the wrapper
    ClippingRectangle {
        anchors.fill: parent

        radius: Tokens.rounding.large
        color: "transparent"

        Repeater {
            id: pages

            model: ScriptModel {
                values: root.dashboardTabs
            }

            // Only the chosen page and, for a short crossfade, the one it replaces exist; the tabs in between never show
            delegate: Loader {
                id: page

                required property int index
                required property var modelData
                readonly property bool shown: index === root.shownIndex

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top

                active: index === root.screenState.dashboardTab || shown || opacity > 0
                asynchronous: true // Built over a few frames, so the morph out of the notch doesn't stall
                visible: opacity > 0
                enabled: shown
                opacity: shown ? 1 : 0
                sourceComponent: modelData.component

                transform: Translate {
                    x: page.slide
                }

                // Incoming pages come from the side of the tab they replace; outgoing ones leave the other way
                property real slide: shown ? 0 : (page.index > root.shownIndex ? 32 : -32)

                Behavior on opacity {
                    enabled: root.animate && root.hasShown

                    Anim {
                        type: Anim.FastEffects
                    }
                }

                Behavior on slide {
                    enabled: root.animate && root.hasShown

                    Anim {
                        type: Anim.FastSpatial
                    }
                }
            }
        }
    }

    Component {
        id: performanceComponent

        Performance {}
    }

    Component {
        id: timerComponent

        TimerTab {}
    }

    Component {
        id: notesComponent

        Notes {}
    }
}
