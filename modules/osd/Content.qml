pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

// Notch contents: icon, accent progress bar and percentage. Scrolling adjusts the volume,
// clicking the icon toggles mute.
CustomMouseArea {
    id: root

    required property string kind
    required property real volume
    required property bool muted
    required property real sourceVolume
    required property bool sourceMuted
    required property real brightness

    readonly property real value: kind === "brightness" ? brightness : kind === "mic" ? sourceVolume : volume
    readonly property real maxValue: kind === "brightness" ? 1 : GlobalConfig.services.maxVolume
    readonly property bool isMuted: kind === "mic" ? sourceMuted : kind === "volume" ? muted : false

    // Animated copy so the bar and number glide while the keys are held
    property real shownValue: value

    function onWheel(event: WheelEvent): void {
        if (event.angleDelta.y > 0)
            Audio.incrementVolume();
        else if (event.angleDelta.y < 0)
            Audio.decrementVolume();
    }

    Behavior on shownValue {
        Anim {
            type: Anim.FastEffects
        }
    }

    Item {
        id: iconBox

        anchors.left: parent.left
        anchors.leftMargin: Tokens.padding.large + Tokens.padding.small
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: icon.implicitWidth
        implicitHeight: icon.implicitHeight

        MaterialIcon {
            id: icon

            anchors.centerIn: parent
            text: {
                if (root.kind === "brightness")
                    return `brightness_${Math.round(root.shownValue * 6) + 1}`;
                if (root.kind === "mic")
                    return Icons.getMicVolumeIcon(root.value, root.sourceMuted);
                return Icons.getVolumeIcon(root.value, root.muted);
            }
            color: root.isMuted ? Colours.palette.m3outline : Colours.palette.m3primary
            fill: 1
            fontStyle: Tokens.font.icon.small
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -Tokens.padding.small
            cursorShape: root.kind === "brightness" ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: {
                const node = root.kind === "mic" ? Audio.source : root.kind === "volume" ? Audio.sink : null;
                if (node?.audio)
                    node.audio.muted = !node.audio.muted;
            }
        }
    }

    StyledRect {
        id: track

        anchors.left: iconBox.right
        anchors.right: percent.left
        anchors.leftMargin: Tokens.spacing.medium
        anchors.rightMargin: Tokens.spacing.medium
        anchors.verticalCenter: parent.verticalCenter
        implicitHeight: 6
        radius: height / 2
        color: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)

        StyledRect {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * Math.max(0, Math.min(1, root.shownValue / root.maxValue))
            radius: parent.radius
            color: root.isMuted ? Colours.palette.m3outline : Colours.palette.m3primary
        }
    }

    StyledText {
        id: percent

        anchors.right: parent.right
        anchors.rightMargin: Tokens.padding.large + Tokens.padding.small
        anchors.verticalCenter: parent.verticalCenter
        width: metrics.width
        horizontalAlignment: Text.AlignRight
        text: `${Math.round(root.shownValue * 100)}%`
        color: Colours.palette.m3onSurface
        font: Tokens.font.body.builders.medium.weight(Font.Medium).build()

        TextMetrics {
            id: metrics

            font: percent.font
            text: "100%"
        }
    }
}
