pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

// Date · time · temperature line drawn inside the top border + Hyprland outer gap.
// Purely visual: no mouse handling, so hover-to-open-dashboard is unaffected.
StyledText {
    id: root

    // Space between the screen edge and windows: border + Hyprland general:gaps_out (10px)
    property real topSpace: Config.border.thickness + 10

    readonly property string dateTime: Qt.formatDateTime(clock.date, "dddd d MMMM") + " · " + Qt.formatDateTime(clock.date, Units.twelveHourClock ? "h:mm AP" : "hh:mm")

    y: Math.round((topSpace - height) / 2)
    text: Weather.cc ? `${dateTime} · ${Weather.temp}` : dateTime
    color: Colours.palette.m3onSurfaceVariant
    font.family: Tokens.font.body.small.family
    font.weight: Font.Medium
    font.pixelSize: 12

    Component.onCompleted: {
        if (!Weather.cc)
            Weather.reload();
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }
}
