pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// The big ring and time display. Scroll on the minutes or seconds to set a custom time.
StyledRect {
    id: root

    readonly property bool stopwatch: TimerState.stopwatch
    readonly property real displayMs: stopwatch ? TimerState.elapsed : TimerState.remaining
    readonly property list<string> parts: TimerState.format(displayMs, !stopwatch).split(":") // Countdowns round up
    readonly property bool showHours: parts.length === 3
    readonly property real progress: {
        if (stopwatch)
            return (TimerState.elapsed % 60000) / 60000;
        if (TimerState.finished)
            return 1;
        return TimerState.duration > 0 ? TimerState.remaining / TimerState.duration : 0;
    }

    readonly property string statusText: {
        if (stopwatch) {
            if (TimerState.swRunning)
                return TimerState.laps.length ? `Lap ${TimerState.laps.length + 1}` : "Running";
            return TimerState.elapsedAtPause > 0 ? "Paused" : "Stopwatch";
        }
        if (TimerState.finished || TimerState.remaining <= 0)
            return "Time's up";
        if (TimerState.timerRunning)
            return `Ends at ${Qt.formatTime(new Date(TimerState.endTime), "hh:mm")}`;
        return TimerState.remaining < TimerState.duration ? "Paused" : "Scroll to set";
    }

    // Moves the ring to the current progress. While running it glides over the second until the next tick
    function syncRing(animate: bool): void {
        ringAnim.stop();
        wrapAnim.stop();
        if (!animate) {
            ring.value = progress;
        } else if (stopwatch && progress < ring.value - 0.5) {
            wrapAnim.start(); // A new minute: finish the circle, then start again from empty
        } else {
            ringAnim.to = progress;
            ringAnim.duration = TimerState.running ? 1000 : Tokens.anim.durations.normal;
            ringAnim.easing.type = TimerState.running ? Easing.Linear : Easing.OutCubic;
            ringAnim.start();
        }
    }

    radius: Tokens.rounding.extraLarge
    color: Colours.tPalette.m3surfaceContainer

    onProgressChanged: syncRing(true)
    Component.onCompleted: {
        syncRing(false);
        if (TimerState.finished)
            acknowledgeTimer.start();
    }

    // Opening the dashboard after the timer finished counts as seeing it, so stop pulsing after a few pulses
    Timer {
        id: acknowledgeTimer

        interval: 5000
        onTriggered: TimerState.acknowledge()
    }

    CircularProgress {
        id: ring

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        strokeWidth: Tokens.padding.medium
        fgColour: TimerState.finished ? Colours.palette.m3tertiary : Colours.palette.m3primary
        bgColour: Colours.palette.m3secondaryContainer

        Behavior on fgColour {
            CAnim {}
        }

        SequentialAnimation on opacity {
            running: TimerState.finished
            loops: Animation.Infinite
            alwaysRunToEnd: true

            NumberAnimation {
                to: 0.35
                duration: 900
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 1
                duration: 900
                easing.type: Easing.InOutSine
            }
        }

        NumberAnimation {
            id: ringAnim

            target: ring
            property: "value"
        }

        SequentialAnimation {
            id: wrapAnim

            NumberAnimation {
                target: ring
                property: "value"
                to: 1
                duration: 1000
            }
            PropertyAction {
                target: ring
                property: "value"
                value: 0
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Tokens.spacing.extraSmall

        MaterialIcon {
            Layout.alignment: Qt.AlignHCenter
            text: root.stopwatch ? "timer" : "hourglass_bottom"
            color: TimerState.finished ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.medium
            fill: TimerState.running ? 1 : 0

            Behavior on fill {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        Row {
            Layout.alignment: Qt.AlignHCenter

            Digits {
                visible: root.showHours
                text: root.parts[0]
            }

            Separator {
                visible: root.showHours
            }

            Digits {
                text: root.parts[root.parts.length - 2]
                step: 60000
            }

            Separator {}

            Digits {
                text: root.parts[root.parts.length - 1]
                step: 1000
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            animate: true
            text: root.statusText
            color: TimerState.finished ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.medium
        }
    }

    component Digits: StyledText {
        id: digits

        property real step // Scroll to change it, when set
        property real wheelDelta

        color: Colours.palette.m3secondary
        font: Tokens.font.clock.size(root.showHours ? 34 : 44).weight(Font.DemiBold).build()

        HoverHandler {
            enabled: digits.step > 0 && !root.stopwatch && !TimerState.timerRunning
            cursorShape: Qt.SizeVerCursor
        }

        WheelHandler {
            enabled: digits.step > 0 && !root.stopwatch && !TimerState.timerRunning
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                digits.wheelDelta += event.angleDelta.y;
                while (Math.abs(digits.wheelDelta) >= 120) {
                    const dir = Math.sign(digits.wheelDelta);
                    TimerState.adjust(dir * digits.step);
                    digits.wheelDelta -= dir * 120;
                }
            }
        }
    }

    component Separator: StyledText {
        text: ":"
        color: Colours.palette.m3primary
        font: Tokens.font.clock.size(root.showHours ? 34 : 44).build()
    }
}
