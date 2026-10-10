pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.dashboard.timer

// The running/paused timer or stopwatch, shown as a small pill in the top border while the dashboard is closed.
// The same item is the shared element of the transition: as the dashboard closes it shrinks and flies from the
// timer dial's digits up into its slot next to the date/time, and back down again as the dashboard opens.
Item {
    id: root

    required property ScreenState screenState
    required property Item dashboard // The dashboard wrapper: its fullOffsetScale drives the flight
    required property Item slot // Where the pill rests (TopInfo.pillSlot)
    required property real fsProgress
    required property int borderHeight

    readonly property bool swActive: TimerState.swRunning || TimerState.elapsedAtPause > 0
    readonly property bool timerActive: TimerState.timerRunning || TimerState.finished || TimerState.remainingAtPause !== TimerState.duration
    // Show the mode on screen if both are going
    readonly property bool showStopwatch: swActive && (TimerState.stopwatch || !timerActive)
    readonly property bool active: swActive || timerActive

    readonly property bool running: showStopwatch ? TimerState.swRunning : TimerState.timerRunning
    readonly property bool finished: !showStopwatch && TimerState.finished
    readonly property bool done: !showStopwatch && !running && TimerState.remaining <= 0
    readonly property real progress: {
        if (showStopwatch)
            return 1;
        if (done)
            return 1;
        return TimerState.duration > 0 ? TimerState.remaining / TimerState.duration : 0;
    }

    // Pulses after finishing until reset or the dashboard is opened
    property bool seen
    readonly property bool pulsing: finished && !seen
    property real pulse: 1

    // 1 when the dashboard is closed, 0 when open
    readonly property real closed: Math.max(0, Math.min(1, dashboard.fullOffsetScale)) // The drawer anim overshoots
    property real presence: active ? 1 : 0

    // The dial's digits, if they are in this screen's dashboard
    readonly property Item source: {
        const digits = TimerState.dialDigits;
        for (let it = digits; it; it = it.parent)
            if (it === dashboard)
                return digits;
        return null;
    }
    readonly property bool flying: source !== null && closed < 1
    // Crossfade with the dial's digits right at the end, so the hand-off doesn't pop
    readonly property real reveal: source ? smooth(Math.min(1, closed / 0.15)) : closed
    readonly property real handoff: source ? presence * reveal : 0
    // Flight progress: shrinks early and rises before sliding across, so it travels on a gentle arc
    readonly property real fly: source ? 1 - Math.pow(1 - closed, 2) : 1
    readonly property real flyX: source ? closed : 1

    function smooth(t: real): real {
        return t * t * (3 - 2 * t);
    }

    function mix(a: color, b: color, t: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }

    // Window-space centre of the pill and its scale for the current flight progress
    readonly property var geometry: {
        void (closed, slot.x, slot.y, slot.width, presence); // Dependencies, the mapped positions don't notify
        const target = slot.mapToItem(parent, slot.width / 2, slot.height / 2);
        if (!source)
            return {
                x: target.x,
                y: target.y,
                scale: 0.85 + 0.15 * closed
            };

        void (source.width, source.height);
        const digits = source.mapToItem(parent, source.width / 2, source.height / 2);
        const fromScale = Math.max(1, source.width / Math.max(1, label.width));
        // Line the label up with the digits, not the whole pill
        const labelOffset = (label.x + label.width / 2 - pill.width / 2) * fromScale;
        return {
            x: digits.x - labelOffset + (target.x - digits.x + labelOffset) * flyX,
            y: digits.y + (target.y - digits.y) * fly,
            scale: fromScale + (1 - fromScale) * fly
        };
    }

    width: pill.width
    height: pill.height
    x: Math.round(geometry.x - width / 2)
    y: Math.round(geometry.y - height / 2)
    scale: geometry.scale * (0.8 + 0.2 * presence)

    opacity: presence * (1 - fsProgress) * reveal * (running || finished ? 1 : 0.65) * pulse
    visible: opacity > 0

    onFinishedChanged: {
        if (finished)
            seen = screenState.dashboard;
    }

    Binding {
        target: TimerState
        property: "dialHandoff"
        value: root.handoff
        when: root.source !== null
    }

    Connections {
        target: root.screenState

        function onDashboardChanged(): void {
            if (root.screenState.dashboard && root.finished)
                root.seen = true;
        }
    }

    Behavior on presence {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    SequentialAnimation on pulse {
        running: root.pulsing
        loops: Animation.Infinite
        alwaysRunToEnd: true

        NumberAnimation {
            to: 0.45
            duration: 900
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: 1
            duration: 900
            easing.type: Easing.InOutSine
        }
    }

    // Clicking opens the full dashboard straight on the timer tab
    HoverHandler {
        enabled: root.active && root.closed === 1
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        enabled: root.active && root.closed === 1
        onTapped: root.openTimerTab()
    }

    function openTimerTab(): void {
        root.screenState.dashboardTab = 1; // Performance, Timer, Notes
        root.screenState.dashboard = true;
        root.screenState.dashboardNotch = false;
    }

    StyledRect {
        id: pill

        anchors.centerIn: parent
        implicitWidth: content.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: Math.min(content.implicitHeight + 4, root.borderHeight - 4)
        radius: Tokens.rounding.full
        color: Qt.alpha(Colours.palette.m3tertiary, 0.16 * root.fly)

        Behavior on implicitWidth {
            Anim {
                type: Anim.FastSpatial
            }
        }

        Row {
            id: content

            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                opacity: root.fly * root.fly // Gone before it reaches the dial
                animate: true
                text: {
                    if (root.finished)
                        return "alarm";
                    if (root.done)
                        return "hourglass_empty";
                    if (!root.running)
                        return "pause";
                    return root.showStopwatch ? "timer" : "hourglass_bottom";
                }
                color: Colours.palette.m3tertiary
                fill: 1
                fontStyle: Tokens.font.icon.small
            }

            Text {
                id: label

                // Fixed width, so the pill (and the date/time next to it) doesn't wobble every second
                width: Math.ceil(metrics.advanceWidth)
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignHCenter
                renderType: root.flying ? Text.QtRendering : Text.NativeRendering // Scales cleanly mid-flight
                text: root.showStopwatch ? TimerState.format(TimerState.elapsed, false) : TimerState.format(TimerState.remaining, true)
                color: root.mix(Colours.palette.m3secondary, Colours.palette.m3tertiary, root.fly)
                font: Tokens.font.body.builders.medium.weight(Font.Medium).build()

                TextMetrics {
                    id: metrics

                    font: label.font
                    text: label.text.replace(/\d/g, "0")
                }
            }
        }
    }
}
