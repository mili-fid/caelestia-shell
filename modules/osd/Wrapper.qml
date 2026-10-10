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
    property bool blocked // The dashboard shape is out: they share the spot, so this waits until it has gone
    readonly property bool shouldBeActive: screenState.osd && Config.osd.enabled && !blocked && !((screenState.dashboard || screenState.dashboardNotch) && Config.dashboard.enabled)
    // Same drop as the dashboard notch: a spring that overshoots past 1 on the way in, spent stretching the shape
    property real drop: shouldBeActive ? 1 : 0
    readonly property real presence: Math.max(0, Math.min(1, drop))
    readonly property real stretch: Math.max(0, drop - 1)
    readonly property real offsetScale: 1 - presence

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

    visible: drop > 0
    clip: true

    // Grows out of the border's edge and outwards, like the dashboard notch
    implicitWidth: notchWidth * (0.6 + 0.4 * presence) + stretch * 120
    implicitHeight: notchHeight * presence + stretch * 60

    Behavior on drop {
        SpringAnimation {
            spring: root.shouldBeActive ? 3.2 : 5
            damping: root.shouldBeActive ? 0.26 : 0.55
            epsilon: 0.002
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
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

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
