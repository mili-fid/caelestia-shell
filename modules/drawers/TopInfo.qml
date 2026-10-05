pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

// Date · time · weather row drawn inside the (taller) top border of the frame.
// Purely visual: no mouse handling, so hover-to-open-dashboard is unaffected.
Item {
    id: root

    // Opacity requested by the parent (dashboard/fullscreen fade), combined with the startup fade-in
    property real shownOpacity: 1
    property real startupProgress: 0

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    opacity: shownOpacity * startupProgress
    visible: opacity > 0

    Component.onCompleted: {
        if (!Weather.cc)
            Weather.reload();
    }

    // Smooth fade-in when the shell starts
    Anim {
        target: root
        property: "startupProgress"
        from: 0
        to: 1
        running: true
        type: Anim.SlowEffects
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.medium

        Segment {
            icon: "calendar_month"
            text: Qt.formatDateTime(clock.date, "dddd d MMMM")
        }

        Dot {}

        Segment {
            icon: "schedule"
            text: Qt.formatDateTime(clock.date, Units.twelveHourClock ? "h:mm AP" : "hh:mm")
        }

        Dot {
            visible: !!Weather.cc
        }

        Segment {
            visible: !!Weather.cc
            icon: Weather.icon
            text: Weather.temp
        }
    }

    component Segment: Row {
        property alias icon: iconItem.text
        property alias text: label.text

        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.small

        MaterialIcon {
            id: iconItem

            anchors.verticalCenter: parent.verticalCenter
            color: Colours.palette.m3primary
            fill: 1
            fontStyle: Tokens.font.icon.small
        }

        StyledText {
            id: label

            anchors.verticalCenter: parent.verticalCenter
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
        }
    }

    component Dot: StyledText {
        anchors.verticalCenter: parent.verticalCenter
        text: "·"
        color: Colours.palette.m3outline
        font: Tokens.font.body.medium
    }
}
