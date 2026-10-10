pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import Caelestia.Services
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.services

// Now-playing row on the right of the top border: [cover] Title · Artist [visualiser] [prev] [play/pause] [next].
// Uses the shared MPRIS service (Players), same as the dashboard's Media tab. Everything is bound to the
// player's properties, which Quickshell updates from MPRIS PropertiesChanged signals (no polling).
// Button presses update the UI optimistically and then follow the player's real state.
// Clicking the cover or the text opens the dashboard on the Media tab.
Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property int borderHeight
    property real shownOpacity: 1
    property real startupProgress: 0
    property real maxWidth: 400 // Room between the date/time (+ timer pill) / dashboard and the right edge

    readonly property var player: Players.active
    readonly property bool hasTrack: !!player && !!(player.trackTitle || player.trackArtist)
    readonly property string title: player?.trackTitle || Tr.tr("Unknown title")
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string artUrl: hasTrack ? Players.getArtUrl(player) : ""

    // What is on screen; swapped in by a quick fade when the track changes
    property string shownTitle
    property string shownArtist

    // Optimistic state, until the player reports back (or gives up)
    property bool pendingPlay
    property bool optimisticPlaying
    property bool skipping
    readonly property bool playing: pendingPlay ? optimisticPlaying : (player?.isPlaying ?? false)

    readonly property int artSize: borderHeight - 4 // 2px clear above and below
    readonly property real artRadius: Tokens.rounding.small * artSize / (borderHeight - 6) // Same corner shape as the old, smaller cover
    readonly property int buttonSize: borderHeight - 2
    readonly property int buttonWidth: buttonSize + 4
    readonly property int buttonGap: Tokens.spacing.small
    readonly property int fast: 150 // Hover
    readonly property int swap: 180 // Icon / track changes, split into a short out and in

    // Mini visualiser: a few thin bars fed from the shared cava service (Audio.cava, same as the background one)
    readonly property int vizBars: 14
    readonly property int vizBarWidth: 3
    readonly property int vizGap: 2
    readonly property int vizWidth: vizBars * vizBarWidth + (vizBars - 1) * vizGap
    readonly property int vizHeight: borderHeight - 8
    readonly property real vizDot: vizBarWidth / vizHeight // Bar height that reads as a round dot

    // Width left for the text after the cover, buttons and spacing
    readonly property real textCap: Math.max(0, Math.min(320, maxWidth - artSize - vizWidth - buttonWidth * 3 - buttonGap * 2 - Tokens.spacing.medium * 3))

    implicitWidth: row.implicitWidth
    implicitHeight: borderHeight
    opacity: shownOpacity * startupProgress
    visible: opacity > 0

    Component.onCompleted: {
        shownTitle = title;
        shownArtist = artist;
        cover.load(artUrl);
    }

    onTitleChanged: trackSwap.restart()
    onArtistChanged: trackSwap.restart()
    onArtUrlChanged: cover.load(artUrl)
    onPlayerChanged: {
        pendingPlay = false;
        skipping = false;
    }

    function togglePlaying(): void {
        optimisticPlaying = !playing;
        pendingPlay = true;
        settle.restart();
        player?.togglePlaying();
    }

    function skip(next: bool): void {
        skipping = true;
        settle.restart();
        if (next)
            player?.next();
        else
            player?.previous();
    }

    Connections {
        target: root.player

        function onIsPlayingChanged(): void {
            root.pendingPlay = false;
        }

        function onPostTrackChanged(): void {
            root.skipping = false;
        }
    }

    // Fall back to the player's state if it never answers
    Timer {
        id: settle

        interval: 1500
        onTriggered: {
            root.pendingPlay = false;
            root.skipping = false;
        }
    }

    // Quick fade out, swap the text, fade back in. Debounced by restart() for players that send title and artist separately
    SequentialAnimation {
        id: trackSwap

        NumberAnimation {
            target: textBox
            property: "swapOpacity"
            to: 0
            duration: root.swap * 0.4
        }
        ScriptAction {
            script: {
                root.shownTitle = root.title;
                root.shownArtist = root.artist;
                root.skipping = false;
            }
        }
        NumberAnimation {
            target: textBox
            property: "swapOpacity"
            to: 1
            duration: root.swap * 0.6
        }
    }

    Anim {
        target: root
        property: "startupProgress"
        from: 0
        to: 1
        running: true
        type: Anim.SlowEffects
    }

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.medium

        // Cover + text: one click target that opens the Media tab
        Item {
            id: info

            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: infoRow.implicitWidth
            implicitHeight: root.borderHeight

            HoverHandler {
                id: infoHover

                enabled: root.hasTrack
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                enabled: root.hasTrack
                onTapped: root.togglePlaying()
            }

            Row {
                id: infoRow

                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.spacing.medium

                Item {
                    id: cover

                    // Two images: the new cover loads in the hidden one and cross-fades in once ready,
                    // so the old one stays up meanwhile instead of blanking
                    property bool frontA: true
                    readonly property Image front: frontA ? imgA : imgB
                    readonly property Image back: frontA ? imgB : imgA
                    readonly property bool hasArt: root.hasTrack && front.status === Image.Ready && front.source.toString() !== ""

                    function load(url: string): void {
                        if (url === front.source.toString())
                            return;
                        back.source = url;
                        if (url === "" || back.status === Image.Ready)
                            frontA = !frontA;
                    }

                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: root.artSize
                    implicitHeight: root.artSize

                    // Note when idle or without art
                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "music_note"
                        color: root.hasTrack ? Colours.palette.m3primary : Colours.palette.m3outline
                        fill: 1
                        fontStyle: Tokens.font.icon.small
                        opacity: cover.hasArt ? 0 : (root.hasTrack ? 1 : 0.6)

                        Behavior on opacity {
                            NumberAnimation {
                                duration: root.swap
                            }
                        }
                    }

                    StyledClippingRect {
                        anchors.fill: parent
                        radius: root.artRadius
                        opacity: root.hasTrack ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: root.swap
                            }
                        }

                        CoverImage {
                            id: imgA

                            shown: cover.frontA
                        }

                        CoverImage {
                            id: imgB

                            shown: !cover.frontA
                        }
                    }
                }

                Item {
                    id: textBox

                    property real swapOpacity: 1
                    readonly property bool overflowing: full.implicitWidth > width + 1
                    readonly property bool scrolling: overflowing && infoHover.hovered

                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: root.hasTrack ? Math.min(full.implicitWidth, root.textCap) : Math.min(idleText.implicitWidth, root.textCap)
                    implicitHeight: root.borderHeight
                    clip: true

                    Behavior on implicitWidth {
                        NumberAnimation {
                            duration: root.swap
                            easing.type: Easing.OutCubic
                        }
                    }

                    StyledText {
                        id: idleText

                        anchors.verticalCenter: parent.verticalCenter
                        text: Tr.tr("Nothing playing")
                        color: Colours.palette.m3outline
                        font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                        opacity: root.hasTrack ? 0 : 1

                        Behavior on opacity {
                            NumberAnimation {
                                duration: root.swap
                            }
                        }
                    }

                    // Holds both text rows; dims while a skip is waiting for the player
                    Item {
                        anchors.fill: parent
                        opacity: (root.hasTrack ? 1 : 0) * textBox.swapOpacity * (root.skipping ? 0.45 : 1)

                        Behavior on opacity {
                            enabled: !trackSwap.running

                            NumberAnimation {
                                duration: root.swap
                            }
                        }

                        // Elided at rest
                        Row {
                            id: elided

                            anchors.verticalCenter: parent.verticalCenter
                            opacity: textBox.scrolling ? 0 : 1

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: root.fast
                                }
                            }

                            TitleText {
                                id: titleText

                                width: Math.min(fullTitle.implicitWidth, textBox.width - (root.shownArtist ? Math.min(fullArtist.implicitWidth, textBox.width * 0.4) + sep.implicitWidth : 0))
                                elide: Text.ElideRight
                            }

                            SepText {
                                id: sep

                                visible: !!root.shownArtist
                            }

                            ArtistText {
                                id: artistText

                                width: Math.max(0, Math.min(fullArtist.implicitWidth, textBox.width - titleText.width - sep.implicitWidth))
                                elide: Text.ElideRight
                            }
                        }

                        // Full text, scrolled slowly while hovered if it doesn't fit
                        Row {
                            id: full

                            property real offset

                            anchors.verticalCenter: parent.verticalCenter
                            x: -offset
                            opacity: textBox.scrolling ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: root.fast
                                }
                            }

                            TitleText {
                                id: fullTitle
                            }

                            SepText {
                                visible: !!root.shownArtist
                            }

                            ArtistText {
                                id: fullArtist
                            }

                            SequentialAnimation {
                                running: textBox.scrolling
                                loops: Animation.Infinite
                                onStopped: full.offset = 0

                                PauseAnimation {
                                    duration: 700
                                }
                                NumberAnimation {
                                    target: full
                                    property: "offset"
                                    from: 0
                                    to: full.implicitWidth - textBox.width
                                    duration: Math.max(600, (full.implicitWidth - textBox.width) * 35)
                                    easing.type: Easing.InOutSine
                                }
                                PauseAnimation {
                                    duration: 1200
                                }
                                NumberAnimation {
                                    target: full
                                    property: "offset"
                                    to: 0
                                    duration: Math.max(600, (full.implicitWidth - textBox.width) * 20)
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }
                    }
                }
            }
        }

        // Placeholder in the row; the bars draw in their own small layer surface on top of it (vizWindow), so each
        // update only redraws those few pixels instead of the whole border window
        Item {
            id: viz

            // Max of each group of cava bars, sampled at ~30fps and written straight to the bars; flat dots when paused or stopped
            function sample(): void {
                const src = root.playing ? Audio.cava.values : [];
                const n = src.length;
                for (let i = 0; i < root.vizBars; i++) {
                    const bar = bars.itemAt(i);
                    if (!bar)
                        continue;
                    let v = 0;
                    if (n > 0) {
                        const from = Math.floor(i * n / root.vizBars);
                        const to = Math.max(from + 1, Math.floor((i + 1) * n / root.vizBars));
                        for (let j = from; j < to; j++)
                            v = Math.max(v, src[j]);
                    }
                    bar.level = Math.max(root.vizDot, Math.min(1, v));
                }
            }

            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: root.vizWidth
            implicitHeight: root.vizHeight

            // Only holds the cava service while playing
            ServiceRef {
                service: root.playing ? Audio.cava : null
            }

            // Nothing runs while paused or stopped
            Timer {
                interval: 33
                repeat: true
                running: root.playing && root.visible
                onRunningChanged: viz.sample() // Settle to dots on pause
                onTriggered: viz.sample()
            }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.buttonGap

            MediaButton {
                icon: "skip_previous"
                disabled: !root.hasTrack || !root.player?.canGoPrevious
                onClicked: root.skip(false)
            }

            MediaButton {
                icon: root.playing ? "pause" : "play_arrow"
                disabled: !root.hasTrack || !root.player?.canTogglePlaying
                onClicked: root.togglePlaying()
            }

            MediaButton {
                icon: "skip_next"
                disabled: !root.hasTrack || !root.player?.canGoNext
                onClicked: root.skip(true)
            }
        }
    }

    // Click-through surface just over the visualiser placeholder, so the border window isn't redrawn per frame
    StyledWindow {
        id: vizWindow

        screen: root.screen
        name: "top-media-visualiser"
        visible: root.visible && root.opacity > 0
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        mask: Region {}
        anchors.top: true
        anchors.left: true
        margins.left: Math.round(root.x + row.x + viz.x)
        margins.top: Math.round(root.y + row.y + viz.y)
        implicitWidth: root.vizWidth
        implicitHeight: root.vizHeight

        // Same look as the background visualiser: rounded tops, primary -> inversePrimary gradient, 0.7 alpha
        Row {
            anchors.bottom: parent.bottom
            spacing: root.vizGap
            clip: true // Hides the bottom rounding
            opacity: root.opacity * (root.hasTrack ? 1 : 0.5)

            Behavior on opacity {
                NumberAnimation {
                    duration: root.swap
                }
            }

            Repeater {
                id: bars

                model: root.vizBars

                Item {
                    id: bar

                    property real level: root.vizDot

                    implicitWidth: root.vizBarWidth
                    implicitHeight: root.vizHeight

                    // Stepped while playing (fewer redraws); eases down to the dots on pause
                    Behavior on level {
                        enabled: !root.playing

                        NumberAnimation {
                            duration: Tokens.anim.durations.normal
                            easing.type: Easing.OutQuad
                        }
                    }

                    // Fixed size and colours, only moved up and down (cheapest update); the part below the bottom is clipped
                    Rectangle {
                        y: root.vizHeight - Math.max(root.vizBarWidth, bar.level * root.vizHeight)
                        width: root.vizBarWidth
                        height: root.vizHeight + radius
                        radius: root.vizBarWidth / 2

                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: Qt.alpha(Colours.palette.m3primary, 0.7)
                            }
                            GradientStop {
                                position: 1
                                color: Qt.alpha(Colours.palette.m3inversePrimary, 0.7)
                            }
                        }
                    }
                }
            }
        }
    }

    component CoverImage: Image {
        id: img

        property bool shown

        anchors.fill: parent
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.artSize * 2, root.artSize * 2)
        opacity: shown && status === Image.Ready ? 1 : 0

        // Bring the freshly loaded cover to the front (or the note icon, if it failed)
        onStatusChanged: {
            if ((status === Image.Ready || status === Image.Error) && !shown && img === cover.back && source.toString() === root.artUrl)
                cover.frontA = !cover.frontA;
        }

        Behavior on opacity {
            NumberAnimation {
                duration: root.swap
            }
        }
    }

    component TitleText: StyledText {
        anchors.verticalCenter: parent?.verticalCenter
        text: root.shownTitle
        color: Colours.palette.m3onSurface
        font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
    }

    component SepText: StyledText {
        anchors.verticalCenter: parent?.verticalCenter
        text: "  ·  "
        color: Colours.palette.m3outline
        font: Tokens.font.body.medium
    }

    component ArtistText: StyledText {
        anchors.verticalCenter: parent?.verticalCenter
        text: root.shownArtist
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.medium
    }

    component MediaButton: Item {
        id: button

        property string icon
        property bool disabled

        signal clicked

        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: root.buttonWidth
        implicitHeight: root.buttonSize
        opacity: disabled ? 0.38 : 1

        // Short dip when the icon changes (play <-> pause)
        Behavior on icon {
            SequentialAnimation {
                NumberAnimation {
                    target: iconItem
                    property: "opacity"
                    to: 0
                    duration: root.swap * 0.4
                }
                PropertyAction {}
                NumberAnimation {
                    target: iconItem
                    property: "opacity"
                    to: 1
                    duration: root.swap * 0.6
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: root.fast
            }
        }

        HoverHandler {
            id: hover

            enabled: !button.disabled
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: tap

            enabled: !button.disabled
            onTapped: button.clicked()
        }

        StyledRect {
            anchors.fill: parent
            radius: Tokens.rounding.full
            color: Colours.palette.m3primary
            opacity: tap.pressed ? 0.22 : hover.hovered ? 0.12 : 0
            scale: tap.pressed ? 0.88 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: root.fast
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: root.fast
                    easing.type: Easing.OutCubic
                }
            }
        }

        MaterialIcon {
            id: iconItem

            anchors.centerIn: parent
            text: button.icon
            color: Colours.palette.m3onSurfaceVariant
            fill: 1
            fontStyle: Tokens.font.icon.large
        }
    }
}
