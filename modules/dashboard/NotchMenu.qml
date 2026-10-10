pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// The small notch shown on hover: one button per dashboard tab. Picking one opens the full dashboard on it.
Item {
    id: root

    required property var tabs

    signal picked(index: int)

    implicitWidth: row.implicitWidth + Tokens.padding.medium * 2
    implicitHeight: row.implicitHeight + Tokens.padding.small * 2

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        Repeater {
            model: root.tabs

            delegate: Item {
                id: button

                required property int index
                required property var modelData
                readonly property bool hovered: stateLayer.containsMouse

                implicitWidth: Math.max(72, label.implicitWidth + Tokens.padding.large * 2)
                implicitHeight: icon.implicitHeight + label.implicitHeight + Tokens.padding.small * 2

                StateLayer {
                    id: stateLayer

                    radius: Tokens.rounding.large
                    color: Colours.palette.m3primary
                    onClicked: root.picked(button.index)
                }

                MaterialIcon {
                    id: icon

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Tokens.padding.small

                    text: button.modelData.iconName
                    color: button.hovered ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                    fill: button.hovered ? 1 : 0
                    fontStyle: Tokens.font.icon.medium
                    scale: button.hovered ? 1.12 : 1

                    Behavior on fill {
                        Anim {
                            type: Anim.FastEffects
                        }
                    }

                    Behavior on scale {
                        Anim {
                            type: Anim.FastSpatial
                        }
                    }

                    Behavior on color {
                        CAnim {}
                    }
                }

                StyledText {
                    id: label

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: icon.bottom

                    text: button.modelData.text
                    color: button.hovered ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium

                    Behavior on color {
                        CAnim {}
                    }
                }
            }
        }
    }
}
