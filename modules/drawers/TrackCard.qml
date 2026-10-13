pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import Caelestia.Config
import qs.components
import qs.services

// Track-change hint: a compact strip hanging under the music widget (TopMedia), right-aligned with it
// and at most 280px wide. Its background is a blob (trackBlobs in ContentWindow), a little more transparent than
// the border, joining it with the same concave shoulders. Children are placed in window coordinates (this item
// is 0x0 at the window origin).
//
// Calm motion, no overshoot: in ~220ms the thumbnail glides in a straight line and grows a little into the strip's
// cover while the strip unfolds shallowly under it; the text fades in just after. Out in ~180ms: the text
// fades, the strip folds back up and the cover returns onto the thumbnail. A track change while out
// cross-fades the cover and text in place.
// Shown ~2.5s per real track change (TrackWatcher), kept while hovered, click = play/pause. Queued while the
// dashboard is out (dropped after 15s). In fullscreen it shows as a pill in the top-right corner (TrackCardPill).
Item {
    id: root

    required property TopMedia media
    required property real topY // Bottom edge of the top border, where the strip hangs from
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

    property bool requested
    readonly property bool shouldShow: requested && !blocked
    readonly property bool hovered: floating ? pillHovered : shapeHover.hovered || coverHover.hovered

    // Animation state: the strip's unfold, the cover's move and the text's fade
    property bool shapeOpen
    property real presence: shapeOpen ? 1 : 0
    property real coverT
    property real textT
    readonly property bool coverLifted: !floating && coverT > 0

    readonly property int cardWidth: Math.min(280, Math.round(media.width))
    readonly property int cardHeight: 48
    readonly property real cardRight: media.x + media.width
    readonly property int inDuration: 220
    readonly property int outDuration: 180

    // Shallow drop: a little narrower while it unfolds
    readonly property real shapeWidth: cardWidth * (0.85 + 0.15 * presence)
    readonly property real shapeHeight: cardHeight * presence

    function togglePlaying(): void {
        if (player?.canTogglePlaying)
            player.togglePlaying();
    }

    onLiveArtUrlChanged: {
        if (artInSync)
            artUrl = liveArtUrl;
    }

    onArtInSyncChanged: {
        if (artInSync)
            artUrl = liveArtUrl;
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

    Behavior on presence {
        NumberAnimation {
            duration: root.shapeOpen ? root.inDuration : root.outDuration - 30
            easing.type: root.shapeOpen ? Easing.OutCubic : Easing.InOutCubic
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

        interval: 2500
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
        NumberAnimation {
            target: root
            property: "coverT"
            to: 1
            duration: root.inDuration
            easing.type: Easing.OutCubic
        }
        SequentialAnimation {
            PauseAnimation {
                duration: 60
            }
            NumberAnimation {
                target: root
                property: "textT"
                to: 1
                duration: root.inDuration - 60
                easing.type: Easing.OutCubic
            }
        }
    }

    ParallelAnimation {
        id: closeAnim

        NumberAnimation {
            target: root
            property: "textT"
            to: 0
            duration: 80
        }
        SequentialAnimation {
            PauseAnimation {
                duration: 30
            }
            ScriptAction {
                script: root.shapeOpen = false
            }
            NumberAnimation {
                target: root
                property: "coverT"
                to: 0
                duration: root.outDuration - 30
                easing.type: Easing.InOutCubic
            }
        }
    }

    Item {
        id: shapeItem

        visible: !root.floating && root.presence > 0
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

    // The shared element: starts exactly on the widget's thumbnail (which hides meanwhile), glides in a straight line
    // into the strip and grows a little, keeping the thumbnail's corner shape
    Item {
        id: flyCover

        readonly property real t: root.coverT
        readonly property real fromX: root.media.x
        readonly property real fromY: root.media.y + (root.media.height - root.media.artSize) / 2
        readonly property real toX: root.cardRight - root.cardWidth + content.coverX
        readonly property real toY: root.topY + content.coverY

        visible: root.coverLifted
        x: fromX + (toX - fromX) * t
        y: fromY + (toY - fromY) * t
        width: root.media.artSize + (content.artSize - root.media.artSize) * t
        height: width

        TrackCover {
            anchors.fill: parent
            artUrl: root.artUrl
            radius: root.media.artRadius * parent.width / root.media.artSize
            loadSize: 72
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
