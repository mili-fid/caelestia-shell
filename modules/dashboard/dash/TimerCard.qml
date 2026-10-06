pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Countdown timer and stopwatch. The state lives in TimerState, so it keeps running while the dashboard is closed.
Item {
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
            return `Ends ${Qt.formatTime(new Date(TimerState.endTime), "hh:mm")}`;
        return TimerState.remaining < TimerState.duration ? "Paused" : "Ready";
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

    anchors.fill: parent
    anchors.margins: Tokens.padding.medium

    // Same height as the weather card this replaced, so the dashboard keeps its size
    implicitHeight: sizer.implicitHeight + Tokens.padding.largeIncreased * 2

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

    MaterialIcon {
        id: sizer

        visible: false
        text: "timer"
        fontStyle: Tokens.font.icon.builders.extraLarge.scale(1.6).build()
    }

    RowLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.medium

        Item {
            Layout.fillHeight: true
            Layout.preferredWidth: height

            CircularProgress {
                id: ring

                anchors.fill: parent
                strokeWidth: Tokens.padding.small
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
                spacing: 0

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
                    Layout.topMargin: -Tokens.spacing.extraSmall
                    text: root.statusText
                    color: TimerState.finished ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.spacing.small

            // Timer / stopwatch switch
            StyledRect {
                id: modeSwitch

                Layout.fillWidth: true
                implicitHeight: timerLabel.implicitHeight + Tokens.padding.small * 2
                radius: Tokens.rounding.full
                color: Colours.tPalette.m3surfaceContainerHigh

                StyledRect {
                    x: root.stopwatch ? parent.width / 2 : 0
                    width: parent.width / 2
                    height: parent.height
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3secondaryContainer

                    Behavior on x {
                        Anim {
                            type: Anim.FastSpatial
                        }
                    }
                }

                ModeOption {
                    id: timerLabel

                    anchors.left: parent.left
                    text: "hourglass_bottom"
                    selected: !root.stopwatch
                    onClicked: TimerState.stopwatch = false
                }

                ModeOption {
                    anchors.right: parent.right
                    text: "timer"
                    selected: root.stopwatch
                    onClicked: TimerState.stopwatch = true
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Presets
                RowLayout {
                    anchors.fill: parent
                    spacing: Tokens.spacing.extraSmall
                    opacity: root.stopwatch ? 0 : 1
                    visible: opacity > 0

                    Behavior on opacity {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }

                    Repeater {
                        model: [5, 10, 25, 45]

                        Preset {}
                    }
                }

                // Latest lap
                RowLayout {
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.extraSmall
                    opacity: root.stopwatch ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }

                    MaterialIcon {
                        text: "flag"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.small
                        fill: TimerState.laps.length ? 1 : 0
                    }

                    StyledText {
                        animate: true
                        text: TimerState.laps.length ? `Lap ${TimerState.laps.length}  ${TimerState.format(TimerState.laps[TimerState.laps.length - 1], false)}` : "No laps yet"
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.medium
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                IconButton {
                    icon: "restart_alt"
                    type: IconButton.Tonal
                    isRound: true
                    font: Tokens.font.icon.small
                    disabled: root.stopwatch ? !TimerState.swRunning && TimerState.elapsedAtPause === 0 : !TimerState.timerRunning && !TimerState.finished && TimerState.remaining === TimerState.duration
                    onClicked: TimerState.reset()
                }

                IconButton {
                    Layout.fillWidth: true
                    icon: TimerState.running ? "pause" : "play_arrow"
                    type: IconButton.Filled
                    isRound: true
                    font: Tokens.font.icon.small
                    onClicked: TimerState.toggle()
                }

                IconButton {
                    icon: root.stopwatch ? "flag" : "more_time"
                    type: IconButton.Tonal
                    isRound: true
                    font: Tokens.font.icon.small
                    disabled: root.stopwatch && !TimerState.swRunning
                    onClicked: root.stopwatch ? TimerState.lap() : TimerState.addMinute()
                }
            }
        }
    }

    component Digits: StyledText {
        id: digits

        property real step // Scroll to change it, when set
        property real wheelDelta

        color: Colours.palette.m3secondary
        font: Tokens.font.clock.size(root.showHours ? 15 : 20).weight(Font.DemiBold).build()

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
        font: Tokens.font.clock.size(root.showHours ? 15 : 20).build()
    }

    component ModeOption: MaterialIcon {
        id: option

        property bool selected

        signal clicked

        anchors.verticalCenter: parent.verticalCenter
        width: parent.width / 2
        horizontalAlignment: Text.AlignHCenter
        color: selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
        fontStyle: Tokens.font.icon.small
        fill: selected ? 1 : 0

        Behavior on fill {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -Tokens.padding.small
            cursorShape: Qt.PointingHandCursor
            onClicked: option.clicked()
        }
    }

    component Preset: StyledRect {
        id: preset

        required property int modelData
        readonly property bool selected: TimerState.duration === modelData * 60000

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.maximumHeight: label.implicitHeight + Tokens.padding.small * 2
        Layout.alignment: Qt.AlignVCenter
        radius: Tokens.rounding.full
        color: selected ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainerHigh
        opacity: TimerState.timerRunning ? 0.5 : 1

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        StateLayer {
            radius: preset.radius
            disabled: TimerState.timerRunning
            onClicked: TimerState.setDuration(preset.modelData * 60000)
        }

        StyledText {
            id: label

            anchors.centerIn: parent
            text: preset.modelData
            color: preset.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
        }
    }
}
