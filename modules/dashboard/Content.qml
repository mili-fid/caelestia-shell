pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components

Item {
    id: root

    required property ScreenState screenState

    // Icons and labels come from the wrapper, which shares them with the small notch
    required property var tabInfo
    readonly property alias view: view
    // Off while morphing out of the notch, so the picked tab shows straight away instead of sliding in
    property bool animate: true
    readonly property var dashboardTabs: {
        const components = [performanceComponent, timerComponent, notesComponent];
        return tabInfo.map((tab, i) => Object.assign({
                component: components[i]
            }, tab));
    }

    // Pages load asynchronously: keep the last ready page's size while the next one builds, so it never collapses
    property real pageWidth
    property real pageHeight

    implicitWidth: pageWidth
    implicitHeight: pageHeight

    Binding on pageWidth {
        when: (root.view.currentItem as Loader)?.status === Loader.Ready
        value: root.view.implicitWidth
        restoreMode: Binding.RestoreNone
    }

    Binding on pageHeight {
        when: (root.view.currentItem as Loader)?.status === Loader.Ready
        value: root.view.implicitHeight
        restoreMode: Binding.RestoreNone
    }

    // The tab strip is the notch's tile row (NotchMenu), which stays on top of this in the wrapper
    ClippingRectangle {
        anchors.fill: parent

        radius: Tokens.rounding.large
        color: "transparent"

        Flickable {
            id: view

            readonly property int currentIndex: root.screenState.dashboardTab
            readonly property Item currentItem: {
                repeater.count; // Trigger update on count change
                return repeater.itemAt(currentIndex);
            }

            anchors.fill: parent

            flickableDirection: Flickable.HorizontalFlick

            implicitWidth: currentItem?.implicitWidth ?? 0
            implicitHeight: currentItem?.implicitHeight ?? 0

            contentX: currentItem?.x ?? 0
            contentWidth: row.implicitWidth
            contentHeight: row.implicitHeight

            onContentXChanged: {
                if (!moving || !currentItem)
                    return;

                const x = contentX - currentItem.x;
                if (x > currentItem.implicitWidth / 2)
                    root.screenState.dashboardTab = Math.min(root.screenState.dashboardTab + 1, root.tabInfo.length - 1);
                else if (x < -currentItem.implicitWidth / 2)
                    root.screenState.dashboardTab = Math.max(root.screenState.dashboardTab - 1, 0);
            }

            onDragEnded: {
                if (!currentItem)
                    return;

                const x = contentX - currentItem.x;
                if (x > currentItem.implicitWidth / 10)
                    root.screenState.dashboardTab = Math.min(root.screenState.dashboardTab + 1, root.tabInfo.length - 1);
                else if (x < -currentItem.implicitWidth / 10)
                    root.screenState.dashboardTab = Math.max(root.screenState.dashboardTab - 1, 0);
                else
                    contentX = Qt.binding(() => currentItem?.x ?? 0);
            }

            RowLayout {
                id: row

                Repeater {
                    id: repeater

                    model: ScriptModel {
                        values: root.dashboardTabs
                    }

                    delegate: Loader {
                        id: paneLoader

                        required property int index
                        required property var modelData

                        Layout.alignment: Qt.AlignTop

                        asynchronous: true // Built over a few frames, so the morph out of the notch doesn't stall
                        sourceComponent: modelData.component

                        Component.onCompleted: active = Qt.binding(() => {
                            if (index === view.currentIndex)
                                return true;
                            const vx = Math.floor(view.visibleArea.xPosition * view.contentWidth);
                            const vex = Math.floor(vx + view.visibleArea.widthRatio * view.contentWidth);
                            return (vx >= x && vx <= x + implicitWidth) || (vex >= x && vex <= x + implicitWidth);
                        })
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

            Behavior on contentX {
                enabled: root.animate

                Anim {}
            }
        }
    }
}
