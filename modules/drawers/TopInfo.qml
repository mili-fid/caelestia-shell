pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

// Date · time · weather row drawn inside the (taller) top border of the frame.
// Purely visual: no mouse handling, so hover-to-open-dashboard is unaffected.
// Makes room on its right for the timer pill (TimerPill), which sits in pillSlot.
Item {
    id: root

    // Opacity requested by the parent (dashboard/fullscreen fade), combined with the startup fade-in
    property real shownOpacity: 1
    property real startupProgress: 0

    // Width of the timer pill, and how much room to make for it (0-1)
    property real pillWidth
    property real pillRoom
    readonly property alias pillSlot: pillSlot
    readonly property real reserved: (pillWidth + Tokens.spacing.medium) * pillRoom

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
        anchors.horizontalCenterOffset: -root.reserved / 2 // Keep date/time and the pill centred together
        spacing: Tokens.spacing.medium

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "dd/MM/yyyy")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
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

    Item {
        id: pillSlot

        anchors.left: row.right
        anchors.leftMargin: Tokens.spacing.medium * root.pillRoom
        anchors.verticalCenter: row.verticalCenter
        width: root.pillWidth
        height: row.height
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
