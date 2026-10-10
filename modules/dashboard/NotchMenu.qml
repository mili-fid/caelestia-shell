pragma ComponentBehavior: Bound

import "timer"
import QtQuick
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils

// One live tile per dashboard section. On hover this row is the whole notch; once a tile is picked the notch grows
// into the full window and the same row stays on top as its tab strip, so nothing is swapped out mid-morph.
// Everything here only exists while the notch or window is out, so nothing polls or ticks while closed.
Item {
    id: root

    required property ScreenState screenState
    required property var tabs
    required property real expanded // 0 = small notch, 1 = full window
    required property real presence // How far the notch has dropped out of the border (drives the stagger)

    readonly property int tileHeight: 52
    readonly property int spacing: 6
    readonly property real tileWidth: (width - spacing * (tabs.length - 1)) / tabs.length
    readonly property int hoveredIndex: {
        for (let i = 0; i < tiles.count; i++)
            if (tiles.itemAt(i)?.hovered)
                return i;
        return -1;
    }
    // Small notch: the highlight follows the pointer. Full window: it marks the current tab
    readonly property bool fullMode: expanded > 0.5
    readonly property int targetIndex: fullMode ? screenState.dashboardTab : hoveredIndex
    property int lastIndex: Math.max(0, screenState.dashboardTab)

    signal picked(index: int)

    onTargetIndexChanged: {
        if (targetIndex >= 0)
            lastIndex = targetIndex;
    }

    implicitHeight: tileHeight

    function onWheel(event: WheelEvent): void {
        if (!fullMode)
            return;
        if (event.angleDelta.y < 0)
            screenState.dashboardTab = Math.min(screenState.dashboardTab + 1, tabs.length - 1);
        else if (event.angleDelta.y > 0)
            screenState.dashboardTab = Math.max(screenState.dashboardTab - 1, 0);
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.onWheel(event)
    }

    // Live CPU/RAM for the tiles, read straight from /proc every 1.5s. Much lighter than the Cpu/Memory services
    // (which also gather temperatures and the like for the Performance page)
    QtObject {
        id: usage

        property real cpu
        property real memory
        property var last: null
        property int samples

        function sample(): void {
            stat.reload();
            meminfo.reload();
            const t = stat.text().split("\n")[0].trim().split(/\s+/).slice(1, 9).map(Number);
            const idle = t[3] + t[4];
            const total = t.reduce((a, b) => a + b, 0);
            if (last && total > last.total)
                cpu = 1 - (idle - last.idle) / (total - last.total);
            last = {
                idle,
                total
            };
            samples++;
            const m = meminfo.text();
            const kb = key => Number((m.match(new RegExp(`${key}:\\s+(\\d+)`)) ?? [0, 0])[1]);
            const memTotal = kb("MemTotal");
            if (memTotal > 0)
                memory = 1 - kb("MemAvailable") / memTotal;
        }
    }

    FileView {
        id: stat

        path: "/proc/stat"
        blockLoading: true
    }

    FileView {
        id: meminfo

        path: "/proc/meminfo"
        blockLoading: true
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: usage.samples > 1 ? 1500 : 250 // A quick second read, so the CPU figure shows straight away
        onTriggered: usage.sample()
    }

    FileView {
        id: notesFile

        readonly property var notes: {
            try {
                return JSON.parse(text()) ?? [];
            } catch (e) {
                return [];
            }
        }

        path: `${Paths.state}/notes.json`
        printErrors: false
        watchChanges: true // The notes tab saves while the window is open
        onFileChanged: reload()
    }

    // The highlight: two edges on springs of different stiffness, so it stretches as it glides between tiles
    Item {
        id: highlight

        property real lead: root.lastIndex
        property real trail: root.lastIndex
        readonly property real step: root.tileWidth + root.spacing

        x: Math.min(lead, trail) * step
        width: Math.abs(lead - trail) * step + root.tileWidth
        height: root.tileHeight
        opacity: root.targetIndex >= 0 ? 1 : 0
        scale: root.targetIndex >= 0 ? 1 : 0.92

        Behavior on lead {
            SpringAnimation {
                spring: 5
                damping: 0.38
                epsilon: 0.002
            }
        }

        Behavior on trail {
            SpringAnimation {
                spring: 3
                damping: 0.4
                epsilon: 0.002
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }

        Behavior on scale {
            Anim {
                type: Anim.FastSpatial
            }
        }

        StyledRect {
            anchors.fill: parent
            radius: Tokens.rounding.large
            color: Colours.palette.m3secondaryContainer
        }
    }

    Repeater {
        id: tiles

        model: root.tabs

        delegate: Item {
            id: tile

            required property int index
            required property var modelData
            readonly property bool hovered: mouse.containsMouse
            readonly property bool lit: root.targetIndex === index
            // Tiles drop in from the centre outwards
            readonly property real appear: {
                const delay = Math.abs(index - (root.tabs.length - 1) / 2) * 0.16;
                const t = Math.max(0, Math.min(1, (root.presence - delay) / (1 - delay)));
                return t * t * (3 - 2 * t);
            }

            x: index * (root.tileWidth + root.spacing)
            width: root.tileWidth
            height: root.tileHeight
            opacity: appear

            transform: Translate {
                y: (1 - tile.appear) * -10
            }

            StateLayer {
                id: mouse

                radius: Tokens.rounding.large
                color: Colours.palette.m3onSurface
                showHoverBackground: root.fullMode && !tile.lit // The highlight covers it otherwise
                onClicked: root.picked(tile.index)
            }

            Row {
                id: row

                anchors.centerIn: parent
                spacing: Tokens.spacing.medium
                scale: mouse.pressed ? 0.96 : 1

                Behavior on scale {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }

                // Icon in a live ring (CPU load / timer progress), or a tonal disc for notes
                Item {
                    id: badge

                    readonly property real ringValue: tile.index === 0 ? usage.cpu : tile.index === 1 ? timerInfo.progress : 0

                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 38
                    implicitHeight: 38

                    StyledRect {
                        anchors.fill: parent
                        anchors.margins: tile.index < 2 ? 7 : 4 // Clear of the ring
                        radius: Tokens.rounding.full
                        color: tile.lit ? Colours.palette.m3primary : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

                        Behavior on color {
                            CAnim {
                                duration: Tokens.anim.durations.normal
                            }
                        }
                    }

                    CircularProgress {
                        anchors.fill: parent
                        visible: tile.index < 2
                        strokeWidth: 3
                        spacing: 4
                        value: badge.ringValue
                        fgColour: tile.index === 1 && timerInfo.finished ? Colours.palette.m3tertiary : Colours.palette.m3primary
                        bgColour: tile.lit ? Qt.alpha(Colours.palette.m3onSecondaryContainer, 0.15) : Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)

                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: tile.modelData.iconName
                        color: tile.lit ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                        fill: tile.lit || tile.hovered ? 1 : 0
                        fontStyle: Tokens.font.icon.small

                        Behavior on fill {
                            Anim {
                                type: Anim.FastEffects
                            }
                        }

                        Behavior on color {
                            CAnim {
                                duration: Tokens.anim.durations.normal
                            }
                        }
                    }
                }

                Column {
                    readonly property real maxWidth: root.tileWidth - badge.implicitWidth - row.spacing - 16

                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        width: Math.min(implicitWidth, parent.maxWidth)
                        text: tile.modelData.text
                        color: tile.lit ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        font: Tokens.font.label.builders.large.weight(Font.DemiBold).build()
                        elide: Text.ElideRight

                        Behavior on color {
                            CAnim {
                                duration: Tokens.anim.durations.normal
                            }
                        }
                    }

                    StyledText {
                        width: Math.min(implicitWidth, parent.maxWidth)
                        text: tile.index === 0 ? perfInfo.text : tile.index === 1 ? timerInfo.text : notesInfo.text
                        color: tile.index === 1 && timerInfo.finished ? Colours.palette.m3tertiary : tile.lit ? Qt.alpha(Colours.palette.m3onSecondaryContainer, 0.8) : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.medium
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    QtObject {
        id: perfInfo

        readonly property string text: `CPU ${Strings.percentOne(usage.cpu)} · RAM ${Strings.percentOne(usage.memory)}`
    }

    QtObject {
        id: timerInfo

        readonly property bool swActive: TimerState.swRunning || TimerState.elapsedAtPause > 0
        readonly property bool timerActive: TimerState.timerRunning || TimerState.finished || TimerState.remainingAtPause !== TimerState.duration
        readonly property bool showStopwatch: swActive && (TimerState.stopwatch || !timerActive)
        readonly property bool finished: !showStopwatch && TimerState.finished
        readonly property real progress: {
            if (showStopwatch)
                return (TimerState.elapsed % 60000) / 60000;
            return TimerState.duration > 0 ? TimerState.remaining / TimerState.duration : 0;
        }
        readonly property string text: {
            if (finished)
                return Tr.tr("Time's up!");
            if (showStopwatch)
                return `${TimerState.swRunning ? "▶" : "❚❚"}  ${TimerState.format(TimerState.elapsed, false)}`;
            if (timerActive)
                return `${TimerState.timerRunning ? "▶" : "❚❚"}  ${TimerState.format(TimerState.remaining, true)}`;
            return Tr.tr("%1 ready").arg(TimerState.format(TimerState.duration, true));
        }
    }

    QtObject {
        id: notesInfo

        readonly property var first: notesFile.notes.find(n => (n.title ?? "").trim() || (n.text ?? "").trim())
        readonly property string text: {
            const count = notesFile.notes.length;
            if (!count)
                return Tr.tr("Jot something down");
            const title = ((first?.title ?? "").trim() || (first?.text ?? "").trim()).split("\n")[0];
            return title ? `${count} · ${title}` : Tr.tr("%1 notes").arg(count);
        }
    }
}
