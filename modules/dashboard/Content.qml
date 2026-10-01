pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.filedialog

Item {
    id: root

    required property ScreenState screenState
    required property FileDialog facePicker
    property Item plugins // Optional PluginLoader; the built-in tabs work without it

    readonly property var builtinTabs: {
        const allTabs = [
            {
                key: "dashboard",
                component: dashComponent,
                iconName: "dashboard",
                text: Tr.tr("Dashboard"),
                enabled: Config.dashboard.showDashboard
            },
            {
                key: "media",
                component: mediaComponent,
                iconName: "queue_music",
                text: Tr.tr("Media"),
                enabled: Config.dashboard.showMedia
            },
            {
                key: "performance",
                component: performanceComponent,
                iconName: "speed",
                text: Tr.tr("Performance"),
                enabled: Config.dashboard.showPerformance
            },
            {
                key: "weather",
                component: weatherComponent,
                iconName: "cloud",
                text: Tr.tr("Weather"),
                enabled: Config.dashboard.showWeather
            }
        ];
        return allTabs.filter(tab => tab.enabled);
    }
    readonly property var dashboardTabs: builtinTabs.concat(plugins?.tabs ?? [])
    readonly property string tabKeys: dashboardTabs.map(t => `${t.key}|${t.iconName}|${t.text}`).join("\n")

    // The selected tab is remembered by key, so it survives tabs being added or removed before it
    property string currentKey
    property bool ready

    function syncCurrentTab(): void {
        if (!ready)
            return;
        const index = dashboardTabs.findIndex(t => t.key === currentKey);
        if (index < 0)
            currentKey = dashboardTabs[0]?.key ?? ""; // The selected tab is gone (e.g. its plugin was disabled), go back to the first tab
        const target = Math.max(0, index);
        if (screenState.dashboardTab !== target)
            screenState.dashboardTab = target;
    }

    readonly property real nonAnimWidth: view.implicitWidth + viewWrapper.anchors.margins * 2
    readonly property real nonAnimHeight: tabs.implicitHeight + tabs.anchors.topMargin + view.implicitHeight + viewWrapper.anchors.margins * 2

    implicitWidth: nonAnimWidth
    implicitHeight: nonAnimHeight

    Component.onCompleted: {
        currentKey = dashboardTabs[screenState.dashboardTab]?.key ?? "";
        ready = true;
        syncCurrentTab();
    }
    onDashboardTabsChanged: syncCurrentTab()

    Connections {
        function onDashboardTabChanged(): void {
            const tab = root.dashboardTabs[root.screenState.dashboardTab];
            if (tab && root.ready)
                root.currentKey = tab.key;
            else
                root.syncCurrentTab(); // Never leave the dashboard on a tab that doesn't exist
        }

        target: root.screenState
    }

    // Tab buttons added to an existing tab bar don't render, so rebuild it whenever the tab list really changes
    Loader {
        id: tabs

        property var tabList // Only replaced on a rebuild, as the old tab bar can't take new buttons
        readonly property string tabKeys: root.tabKeys

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: CUtils.clamp(anchors.margins - Config.border.thickness, 0, anchors.margins)
        anchors.margins: Tokens.padding.large

        active: false
        Component.onCompleted: {
            tabList = root.dashboardTabs;
            active = true;
        }
        onTabKeysChanged: {
            if (!active)
                return;
            active = false;
            tabList = root.dashboardTabs;
            active = true;
        }

        sourceComponent: Tabs {
            nonAnimWidth: root.nonAnimWidth - tabs.anchors.margins * 2
            screenState: root.screenState
            tabs: tabs.tabList
        }
    }

    ClippingRectangle {
        id: viewWrapper

        anchors.top: tabs.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.padding.large

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
                    root.screenState.dashboardTab = Math.min(root.screenState.dashboardTab + 1, root.dashboardTabs.length - 1);
                else if (x < -currentItem.implicitWidth / 2)
                    root.screenState.dashboardTab = Math.max(root.screenState.dashboardTab - 1, 0);
            }

            onDragEnded: {
                if (!currentItem)
                    return;

                const x = contentX - currentItem.x;
                if (x > currentItem.implicitWidth / 10)
                    root.screenState.dashboardTab = Math.min(root.screenState.dashboardTab + 1, root.dashboardTabs.length - 1);
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

                        sourceComponent: modelData.component
                        onStatusChanged: {
                            if (status === Loader.Error && modelData.pluginId)
                                root.plugins?.markFailed(modelData.pluginId, "The tab could not be created, see the shell log for details");
                        }

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
                id: dashComponent

                Dash {
                    screenState: root.screenState
                    facePicker: root.facePicker
                }
            }

            Component {
                id: mediaComponent

                Media {
                    screenState: root.screenState
                }
            }

            Component {
                id: performanceComponent

                Performance {}
            }

            Component {
                id: weatherComponent

                WeatherTab {}
            }

            Behavior on contentX {
                Anim {}
            }
        }
    }

    Behavior on implicitWidth {
        Anim {}
    }

    Behavior on implicitHeight {
        Anim {}
    }
}
