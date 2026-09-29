pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.utils

// Loads dashboard tab plugins from ~/.config/caelestia/plugins/<id>/ (manifest.json + Main.qml).
// Each plugin is compiled on its own, so a broken plugin is reported instead of breaking the dashboard.
Item {
    id: root

    readonly property string dir: `${Paths.config}/plugins`
    property var tabs: []
    property var failures: ({})

    function refresh(): void {
        const tabs = [];
        const statuses = {};
        for (let i = 0; i < instantiator.count; i++) {
            const plugin = instantiator.objectAt(i) as Plugin;
            if (!plugin?.ready)
                continue;

            const error = plugin.error || failures[plugin.pluginId];
            if (!plugin.enabled)
                statuses[plugin.pluginId] = {
                    status: "disabled"
                };
            else if (error)
                statuses[plugin.pluginId] = {
                    status: "failed",
                    error
                };
            else
                statuses[plugin.pluginId] = {
                    status: "loaded"
                };

            if (plugin.enabled && plugin.component && !error)
                tabs.push({
                    pluginId: plugin.pluginId,
                    component: plugin.component,
                    iconName: plugin.icon || "extension",
                    text: plugin.name || plugin.pluginId,
                    enabled: true
                });
        }
        root.tabs = tabs;
        statusFile.setText(JSON.stringify(statuses, null, 2));
    }

    // Called when a plugin compiles but its tab fails to be created
    function markFailed(pluginId: string, error: string): void {
        failures[pluginId] = error;
        Qt.callLater(refresh);
    }

    FolderListModel {
        id: folders

        folder: `file://${root.dir}`
        showFiles: false
        showDirs: true
        showHidden: false // New plugins are written to a hidden folder, then renamed into place
    }

    Instantiator {
        id: instantiator

        model: folders
        onObjectAdded: Qt.callLater(root.refresh)
        onObjectRemoved: Qt.callLater(root.refresh)

        Plugin {}
    }

    FileView {
        id: statusFile

        printErrors: false
        path: `${Paths.state}/plugin-status.json`
    }

    component Plugin: QtObject {
        id: plugin

        required property string fileName
        required property string filePath

        readonly property string pluginId: fileName
        property bool ready
        property string name
        property string icon
        property bool enabled
        property Component component
        property string error

        function load(): void {
            if (!enabled) {
                component = null;
                return;
            }
            if (component || error)
                return;

            const comp = Qt.createComponent(`file://${filePath}/Main.qml`, Component.PreferSynchronous);
            if (comp.status === Component.Ready) {
                component = comp;
            } else {
                error = comp.errorString().trim() || "Failed to load Main.qml";
                comp.destroy();
            }
        }

        readonly property FileView manifest: FileView {
            path: `${plugin.filePath}/manifest.json`
            printErrors: false
            watchChanges: true
            onFileChanged: reload()
            onLoaded: {
                try {
                    const data = JSON.parse(text());
                    plugin.name = data.name ?? "";
                    plugin.icon = data.icon ?? "";
                    plugin.enabled = data.enabled !== false;
                    if (plugin.error.startsWith("manifest.json"))
                        plugin.error = "";
                } catch (e) {
                    plugin.enabled = true; // Show as failed rather than silently disabled
                    plugin.error = `manifest.json: ${e}`;
                }
                if (!plugin.enabled)
                    delete root.failures[plugin.pluginId];
                plugin.ready = true;
                plugin.load();
                Qt.callLater(root.refresh);
            }
            onLoadFailed: err => {
                plugin.enabled = true;
                plugin.error = "manifest.json is missing or unreadable";
                plugin.ready = true;
                Qt.callLater(root.refresh);
            }
        }
    }
}
