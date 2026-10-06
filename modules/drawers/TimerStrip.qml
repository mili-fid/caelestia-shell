pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.dashboard.timer

// Thin line along the bottom edge of the top border, in the timer pill's colour.
// Countdown: drains with the remaining time. Stopwatch: a faint line with a slow shimmer while running.
Item {
    id: root

    required property TimerPill pill

    readonly property bool stopwatch: pill.showStopwatch
    readonly property real shownOpacity: pill.presence * pill.closed * (1 - pill.fsProgress)

    implicitHeight: 2
    opacity: shownOpacity * (pill.running || pill.finished ? 0.9 : 0.55) * pill.pulse
    visible: opacity > 0

    // Countdown
    StyledRect {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * (root.stopwatch ? 0 : root.pill.progress)
        visible: !root.stopwatch
        radius: Tokens.rounding.full
        color: Colours.palette.m3tertiary

        // Short glide per one-second tick, so it doesn't redraw continuously
        Behavior on width {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    // Stopwatch
    StyledRect {
        id: track

        anchors.fill: parent
        visible: root.stopwatch
        radius: Tokens.rounding.full
        color: Qt.alpha(Colours.palette.m3tertiary, 0.35)
        clip: true

        Rectangle {
            id: shimmer

            property real pos: 0

            x: (track.width + width) * pos - width
            visible: root.pill.running
            width: Math.min(220, track.width / 4)
            height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: 0.5
                    color: Colours.palette.m3tertiary
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }

            // A sweep, then a rest, and only while it can be seen
            SequentialAnimation on pos {
                running: root.stopwatch && root.pill.running && root.shownOpacity > 0
                loops: Animation.Infinite

                PropertyAction {
                    value: 0
                }
                NumberAnimation {
                    to: 1
                    duration: 1800
                    easing.type: Easing.InOutSine
                }
                PauseAnimation {
                    duration: 2200
                }
            }
        }
    }
}
