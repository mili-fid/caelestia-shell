import "timer"
import QtQuick
import QtQuick.Layouts
import Caelestia.Config

// Countdown timer and stopwatch. The state lives in TimerState, so it keeps running while the dashboard is closed.
Item {
    id: root

    implicitWidth: 840 // Same width as the dashboard and notes tabs
    implicitHeight: Tokens.sizes.dashboard.mediaTabHeight

    RowLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.medium

        TimerDial {
            Layout.fillHeight: true
            Layout.preferredWidth: height
        }

        TimerControls {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
