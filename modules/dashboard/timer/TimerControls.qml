pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

// Mode switch, presets and custom time (or laps for the stopwatch), and the start/pause controls
StyledRect {
    id: root

    readonly property bool stopwatch: TimerState.stopwatch
    readonly property real setMs: TimerState.timerRunning || TimerState.remaining <= 0 ? TimerState.duration : TimerState.remaining

    radius: Tokens.rounding.extraLarge
    color: Colours.tPalette.m3surfaceContainer

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            MaterialIcon {
                Layout.topMargin: Math.round(fontInfo.pointSize * 0.12)
                animate: true
                text: root.stopwatch ? "timer" : "hourglass_bottom"
                fontStyle: Tokens.font.icon.medium
            }

            StyledText {
                Layout.fillWidth: true
                animate: true
                text: root.stopwatch ? "Stopwatch" : "Timer"
                font: Tokens.font.title.medium
            }

            // Timer / stopwatch switch
            StyledRect {
                implicitWidth: Math.max(timerOption.implicitWidth, stopwatchOption.implicitWidth) * 2
                implicitHeight: timerOption.implicitHeight
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
                    id: timerOption

                    anchors.left: parent.left
                    width: parent.width / 2
                    icon: "hourglass_bottom"
                    text: "Timer"
                    selected: !root.stopwatch
                    onClicked: TimerState.stopwatch = false
                }

                ModeOption {
                    id: stopwatchOption

                    anchors.right: parent.right
                    width: parent.width / 2
                    icon: "timer"
                    text: "Stopwatch"
                    selected: root.stopwatch
                    onClicked: TimerState.stopwatch = true
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Timer: presets and custom time
            ColumnLayout {
                anchors.fill: parent
                spacing: Tokens.spacing.small
                opacity: root.stopwatch ? 0 : 1
                visible: opacity > 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                SectionLabel {
                    text: "Presets"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    Repeater {
                        model: [5, 10, 25, 45]

                        Preset {}
                    }
                }

                SectionLabel {
                    Layout.topMargin: Tokens.spacing.small
                    text: "Custom time"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    Stepper {
                        value: Math.floor(Math.round(root.setMs / 1000) / 60)
                        unit: "min"
                        step: 60000
                    }

                    Stepper {
                        value: Math.round(root.setMs / 1000) % 60
                        unit: "sec"
                        step: 1000
                    }
                }

                Item {
                    Layout.fillHeight: true
                }
            }

            // Stopwatch: laps, newest first
            Item {
                anchors.fill: parent
                opacity: root.stopwatch ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small
                    opacity: TimerState.laps.length ? 0 : 1
                    visible: opacity > 0

                    Behavior on opacity {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "flag"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.large
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No laps yet"
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.medium
                    }
                }

                VerticalFadeListView {
                    id: laps

                    anchors.fill: parent
                    clip: true
                    spacing: Tokens.spacing.extraSmall
                    model: TimerState.laps.length

                    add: Transition {
                        Anim {
                            type: Anim.DefaultEffects
                            property: "opacity"
                            from: 0
                            to: 1
                        }
                    }

                    displaced: Transition {
                        Anim {
                            property: "y"
                        }
                    }

                    delegate: StyledRect {
                        id: lap

                        required property int index
                        readonly property int number: TimerState.laps.length - index
                        readonly property real total: TimerState.laps.slice(0, number).reduce((sum, l) => sum + l, 0)

                        width: laps.width
                        implicitHeight: lapRow.implicitHeight + Tokens.padding.small * 2
                        radius: Tokens.rounding.full
                        color: Colours.tPalette.m3surfaceContainerHigh

                        RowLayout {
                            id: lapRow

                            anchors.fill: parent
                            anchors.leftMargin: Tokens.padding.large
                            anchors.rightMargin: Tokens.padding.large
                            spacing: Tokens.spacing.medium

                            StyledText {
                                Layout.fillWidth: true
                                text: `Lap ${lap.number}`
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.body.medium
                            }

                            StyledText {
                                text: TimerState.format(TimerState.laps[lap.number - 1] ?? 0, false)
                                color: Colours.palette.m3primary
                                font: Tokens.font.title.small
                            }

                            StyledText {
                                text: TimerState.format(lap.total, false)
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.body.small
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            IconTextButton {
                icon: "restart_alt"
                text: "Reset"
                type: IconTextButton.Tonal
                disabled: root.stopwatch ? !TimerState.swRunning && TimerState.elapsedAtPause === 0 : !TimerState.timerRunning && !TimerState.finished && TimerState.remaining === TimerState.duration
                onClicked: TimerState.reset()
            }

            IconTextButton {
                icon: root.stopwatch ? "flag" : "more_time"
                text: root.stopwatch ? "Lap" : "+1 min"
                type: IconTextButton.Tonal
                disabled: root.stopwatch && !TimerState.swRunning
                onClicked: root.stopwatch ? TimerState.lap() : TimerState.addMinute()
            }

            Item {
                Layout.fillWidth: true
            }

            IconTextButton {
                Layout.preferredWidth: Math.max(implicitWidth, 140)
                icon: TimerState.running ? "pause" : "play_arrow"
                text: TimerState.running ? "Pause" : (root.stopwatch ? TimerState.elapsedAtPause > 0 : TimerState.remaining < TimerState.duration && TimerState.remaining > 0) ? "Resume" : "Start"
                type: IconTextButton.Filled
                onClicked: TimerState.toggle()
            }
        }
    }

    component SectionLabel: StyledText {
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.label.large
    }

    component ModeOption: Item {
        id: option

        required property string icon
        required property string text
        property bool selected

        signal clicked

        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: optionRow.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: optionRow.implicitHeight + Tokens.padding.small * 2

        StateLayer {
            radius: Tokens.rounding.full
            onClicked: option.clicked()
        }

        RowLayout {
            id: optionRow

            anchors.centerIn: parent
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                text: option.icon
                color: option.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
                fill: option.selected ? 1 : 0

                Behavior on fill {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            StyledText {
                text: option.text
                color: option.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.large
            }
        }
    }

    component Preset: StyledRect {
        id: preset

        required property int modelData
        readonly property bool selected: !TimerState.timerRunning && TimerState.duration === modelData * 60000

        Layout.fillWidth: true
        implicitHeight: presetLabel.implicitHeight + Tokens.padding.medium * 2
        radius: selected ? Tokens.rounding.large : Tokens.rounding.full
        color: selected ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainerHigh
        opacity: TimerState.timerRunning ? 0.5 : 1

        Behavior on radius {
            Anim {}
        }

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
            id: presetLabel

            anchors.centerIn: parent
            text: `${preset.modelData} min`
            color: preset.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
            font: Tokens.font.title.small
        }
    }

    component Stepper: StyledRect {
        id: stepper

        required property int value
        required property string unit
        required property real step
        property real wheelDelta

        Layout.fillWidth: true
        implicitHeight: stepperRow.implicitHeight + Tokens.padding.extraSmall * 2
        radius: Tokens.rounding.full
        color: Colours.tPalette.m3surfaceContainerHigh
        opacity: TimerState.timerRunning ? 0.5 : 1

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        WheelHandler {
            enabled: !TimerState.timerRunning
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                stepper.wheelDelta += event.angleDelta.y;
                while (Math.abs(stepper.wheelDelta) >= 120) {
                    const dir = Math.sign(stepper.wheelDelta);
                    TimerState.adjust(dir * stepper.step);
                    stepper.wheelDelta -= dir * 120;
                }
            }
        }

        RowLayout {
            id: stepperRow

            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.extraSmall
            anchors.rightMargin: Tokens.padding.extraSmall

            IconButton {
                icon: "remove"
                type: IconButton.Text
                isRound: true
                disabled: TimerState.timerRunning
                onClicked: TimerState.adjust(-stepper.step)
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: `${String(stepper.value).padStart(2, "0")} ${stepper.unit}`
                font: Tokens.font.title.small
            }

            IconButton {
                icon: "add"
                type: IconButton.Text
                isRound: true
                disabled: TimerState.timerRunning
                onClicked: TimerState.adjust(stepper.step)
            }
        }
    }
}
