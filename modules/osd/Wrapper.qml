pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

// Notch OSD: hangs from the centre of the top border. Its background is a blob in the
// drawers window (osdBg in ContentWindow), so it merges into the border with smooth joins.
// Shown by volume/brightness changes, hidden 1.5s after the last one (or after the pointer leaves).
Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState

    property bool hovered
    readonly property Brightness.Monitor monitor: Brightness.getMonitorForScreen(root.screen)
    readonly property bool shouldBeActive: screenState.osd && Config.osd.enabled && !((screenState.dashboard || screenState.dashboardNotch) && Config.dashboard.enabled) // Shares the spot with the dashboard notch
    property real offsetScale: shouldBeActive ? 0 : 1
    readonly property real presence: Math.max(0, Math.min(1, 1 - offsetScale))

    readonly property int notchWidth: 300
    readonly property int notchHeight: 38

    // Which value the notch shows: "volume", "mic" or "brightness"
    property string kind: "volume"
    property real volume
    property bool muted
    property real sourceVolume
    property bool sourceMuted
    property real brightness

    function show(newKind: string): void {
        kind = newKind;
        screenState.osd = true;
        timer.restart();
    }

    Component.onCompleted: {
        volume = Audio.volume;
        muted = Audio.muted;
        sourceVolume = Audio.sourceVolume;
        sourceMuted = Audio.sourceMuted;
        brightness = root.monitor?.brightness ?? 0;
    }

    onHoveredChanged: {
        if (!hovered && screenState.osd)
            timer.restart();
    }

    visible: offsetScale < 1
    clip: true

    // Grows down out of the border and outwards; the spatial easing overshoots, so it springs
    anchors.topMargin: (-notchHeight - 5) * offsetScale
    implicitWidth: notchWidth * (0.55 + 0.45 * (1 - offsetScale))
    implicitHeight: notchHeight

    Behavior on offsetScale {
        Anim {
            type: root.shouldBeActive ? Anim.DefaultSpatial : Anim.Emphasized
        }
    }

    Connections {
        function onMutedChanged(): void {
            root.muted = Audio.muted;
            root.show("volume");
        }

        function onVolumeChanged(): void {
            root.volume = Audio.volume;
            root.show("volume");
        }

        function onSourceMutedChanged(): void {
            root.sourceMuted = Audio.sourceMuted;
            if (root.Config.osd.enableMicrophone)
                root.show("mic");
        }

        function onSourceVolumeChanged(): void {
            root.sourceVolume = Audio.sourceVolume;
            if (root.Config.osd.enableMicrophone)
                root.show("mic");
        }

        target: Audio
    }

    Connections {
        function onBrightnessChanged(): void {
            root.brightness = root.monitor?.brightness ?? 0;
            if (root.Config.osd.enableBrightness)
                root.show("brightness");
        }

        target: root.monitor
    }

    Timer {
        id: timer

        interval: 1500
        onTriggered: {
            if (!root.hovered)
                root.screenState.osd = false;
        }
    }

    HoverHandler {
        onHoveredChanged: root.hovered = hovered
    }

    Loader {
        anchors.centerIn: parent

        active: root.shouldBeActive || root.visible
        opacity: Math.max(0, root.presence * 2 - 1)

        sourceComponent: Content {
            width: root.notchWidth
            height: root.notchHeight
            kind: root.kind
            volume: root.volume
            muted: root.muted
            sourceVolume: root.sourceVolume
            sourceMuted: root.sourceMuted
            brightness: root.brightness
        }
    }
}
