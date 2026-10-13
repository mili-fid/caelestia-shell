pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.effects
import qs.services

// The track card over a fullscreen window: the border is hidden, so it floats as a pill in the top-right corner
// on its own overlay surface, with the cover drawn inside. Never focused; only the pill itself takes input
// (hover keeps it, click = play/pause). State, timer, spring and text slide come from the TrackCard.
StyledWindow {
    id: root

    required property TrackCard card

    readonly property int gap: contentItem.Tokens.padding.large

    name: "track-card-fullscreen"
    visible: card.floating && card.drop > 0
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {
        item: pill
    }
    anchors.top: true
    anchors.right: true

    onVisibleChanged: {
        if (!visible)
            card.pillHovered = false;
    }

    // Fixed size with room for the overshoot and shadow, so the surface isn't resized every frame
    implicitWidth: card.cardWidth + 40 + gap * 2
    implicitHeight: card.cardHeight + 36 + gap * 2

    Elevation {
        anchors.fill: pill
        radius: pill.radius
        level: 2
        opacity: root.card.presence
    }

    StyledRect {
        id: pill

        anchors.right: parent.right
        anchors.rightMargin: root.gap
        y: root.gap
        width: root.card.shapeWidth
        height: root.card.shapeHeight
        radius: Math.min(height / 2, Tokens.rounding.extraLarge)
        color: Colours.tPalette.m3surface
        clip: true

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: root.card.pillHovered = hovered
        }

        TapHandler {
            onTapped: root.card.togglePlaying()
        }

        TrackCardContent {
            anchors.top: parent.top
            anchors.right: parent.right
            width: root.card.cardWidth
            height: root.card.cardHeight
            opacity: Math.max(0, root.card.presence * 2 - 1)
            title: root.card.watcher.lastTitle
            artist: root.card.watcher.lastArtist
            artUrl: root.card.artUrl
            showCover: true
            reveal: root.card.textT
        }
    }
}
