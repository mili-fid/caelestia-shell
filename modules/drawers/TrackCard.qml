pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services

// Track-change card under the music widget (TopMedia). Its background is a blob in the drawers window
// (trackBg in ContentWindow), so it drips out of the top border with the same concave shoulders as the notches.
// Children are placed in window coordinates (this item is 0x0 at the window origin).
//
// Opening: the widget's thumbnail lifts out (the flying cover, with a shadow that peaks mid-flight) and grows
// along a slight arc into the card's cover slot, while the shape springs down under the widget, narrow first
// and widening as it falls, like a drop. The text slides down into place a moment later.
// Closing: the text fades, then the shape pulls back up into the border while the cover shrinks back into the
// thumbnail. A track change while out cross-fades the cover and text in place.
// Shown ~3s per real track change (TrackWatcher), kept while hovered, click = play/pause. Queued while the
// dashboard is out (dropped after 15s). In fullscreen it shows as a pill in the top-right corner (TrackCardPill).
Item {
    id: root

    required property TopMedia media
    required property real topY // Bottom edge of the top border, where the card hangs from
    property bool blocked
    property bool floating
    property bool pillHovered

    readonly property alias shape: shapeItem
    readonly property alias watcher: tracks

    property MprisPlayer player
    // The cover follows the player only while it reports the card's (real) title, so a page-name title's
    // placeholder art never shows
    readonly property string liveArtUrl: Players.getArtUrl(player)
    readonly property bool artInSync: (player?.trackTitle ?? "") === tracks.lastTitle
    property string artUrl

    onLiveArtUrlChanged: {
        if (artInSync)
            artUrl = liveArtUrl;
    }
    onArtInSyncChanged: {
        if (artInSync)
            artUrl = liveArtUrl;
    }

    property bool requested
    readonly property bool shouldShow: requested && !blocked
    readonly property bool hovered: floating ? pillHovered : shapeHover.hovered || coverHover.hovered

    // Animation state: the shape's spring, the cover's flight and the text's slide
    property bool shapeOpen
    property real coverT
    property real textT
    property real drop: shapeOpen ? 1 : 0
    readonly property real presence: Math.max(0, Math.min(1, drop))
    readonly property real stretch: Math.max(0, drop - 1)
    readonly property bool coverLifted: !floating && coverT > 0

    readonly property int cardWidth: 340
    readonly property int cardHeight: 96
    readonly property real cardRight: media.x + media.width

    // Narrow at first and widening as it falls; right-aligned with the widget
    readonly property real widthT: Math.max(0, Math.min(1, (presence - 0.1) / 0.8))
    readonly property real shapeWidth: cardWidth * (0.45 + 0.55 * widthT) + stretch * 40
    readonly property real shapeHeight: cardHeight * presence + stretch * 36

    function togglePlaying(): void {
        if (player?.canTogglePlaying)
            player.togglePlaying();
    }

    onShouldShowChanged: {
        if (shouldShow) {
            closeAnim.stop();
            openAnim.restart();
            if (!hovered)
                hideTimer.restart();
        } else {
            hideTimer.stop();
            openAnim.stop();
            closeAnim.restart();
        }
    }

    onHoveredChanged: {
        if (hovered)
            hideTimer.stop();
        else if (shouldShow)
            hideTimer.restart();
    }

    onBlockedChanged: {
        if (blocked && requested)
            staleTimer.restart();
    }

    Behavior on drop {
        SpringAnimation {
            spring: root.shapeOpen ? 3.2 : 5
            damping: root.shapeOpen ? 0.26 : 0.55
            epsilon: 0.002
        }
    }

    TrackWatcher {
        id: tracks

        onTrackChanged: {
            root.player = tracks.player;
            if (root.blocked)
                staleTimer.restart();
            if (root.shouldShow && !root.hovered)
                hideTimer.restart();
            root.requested = true;
        }
    }

    Timer {
        id: hideTimer

        interval: 3000
        onTriggered: root.requested = false
    }

    // A card queued behind the dashboard is dropped if it waits too long
    Timer {
        id: staleTimer

        interval: 15000
        onTriggered: {
            if (root.blocked)
                root.requested = false;
        }
    }

    ParallelAnimation {
        id: openAnim

        ScriptAction {
            script: root.shapeOpen = true
        }
        Anim {
            target: root
            property: "coverT"
            to: 1
            type: Anim.DefaultSpatial
        }
        SequentialAnimation {
            PauseAnimation {
                duration: 140
            }
            Anim {
                target: root
                property: "textT"
                to: 1
                type: Anim.DefaultEffects
            }
        }
    }

    SequentialAnimation {
        id: closeAnim

        Anim {
            target: root
            property: "textT"
            to: 0
            duration: 110
            type: Anim.FastEffects
        }
        ScriptAction {
            script: root.shapeOpen = false
        }
        // No overshoot here: the cover must land exactly on the thumbnail
        Anim {
            target: root
            property: "coverT"
            to: 0
            type: Anim.Emphasized
        }
    }

    Item {
        id: shapeItem

        visible: !root.floating && root.drop > 0
        x: root.cardRight - root.shapeWidth
        y: root.topY
        width: root.shapeWidth
        height: root.shapeHeight
        clip: true

        HoverHandler {
            id: shapeHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: root.togglePlaying()
        }

        TrackCardContent {
            id: content

            anchors.top: parent.top
            anchors.right: parent.right
            width: root.cardWidth
            height: root.cardHeight
            title: tracks.lastTitle
            artist: tracks.lastArtist
            artUrl: root.artUrl
            reveal: root.textT
        }
    }

    // The shared element: starts exactly on the widget's thumbnail (which hides meanwhile) and lands in the card
    Item {
        id: flyCover

        readonly property real t: root.coverT
        readonly property real fromX: root.media.x
        readonly property real fromY: root.media.y + (root.media.height - root.media.artSize) / 2
        readonly property real toX: root.cardRight - root.cardWidth + content.coverX
        readonly property real toY: root.topY + content.coverY
        // Falls a little ahead of its sideways move, so the path arcs out of the border
        readonly property real tY: t < 1 ? 1 - Math.pow(1 - Math.max(0, t), 1.6) : t

        visible: root.coverLifted
        x: fromX + (toX - fromX) * t
        y: fromY + (toY - fromY) * tY
        width: root.media.artSize + (content.artSize - root.media.artSize) * t
        height: width

        Elevation {
            anchors.fill: parent
            radius: cover.radius
            level: 3
            opacity: Math.sin(Math.PI * Math.max(0, Math.min(1, flyCover.t))) * 0.9
        }

        TrackCover {
            id: cover

            anchors.fill: parent
            artUrl: root.artUrl
            radius: root.media.artRadius + (Tokens.rounding.medium - root.media.artRadius) * Math.max(0, Math.min(1, flyCover.t))
        }

        HoverHandler {
            id: coverHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: root.togglePlaying()
        }
    }
}
