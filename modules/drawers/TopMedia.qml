pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.images
import qs.services

// Now-playing row on the left of the top border: [cover] Title · Artist [prev] [play/pause] [next].
// Uses the shared MPRIS service (Players), same as the dashboard's Media tab.
// Clicking the cover or the text opens the dashboard on the Media tab.
Item {
    id: root

    required property ScreenState screenState
    required property int borderHeight
    property real shownOpacity: 1
    property real startupProgress: 0
    property real maxWidth: 400 // Room before the dashboard / date-time, set by the parent

    readonly property var player: Players.active
    readonly property bool hasTrack: !!player && !!(player.trackTitle || player.trackArtist)
    readonly property int artSize: borderHeight - 8
    readonly property int buttonSize: borderHeight - 6

    // Width left for the text after the cover, buttons and spacing
    readonly property real textCap: Math.max(0, Math.min(260, maxWidth - artSize - buttonSize * 3 - Tokens.spacing.small * 2 - Tokens.spacing.medium))

    implicitWidth: row.implicitWidth
    implicitHeight: borderHeight
    opacity: shownOpacity * startupProgress
    visible: opacity > 0

    Anim {
        target: root
        property: "startupProgress"
        from: 0
        to: 1
        running: true
        type: Anim.SlowEffects
    }

    function openMediaTab(): void {
        if (!Config.dashboard.showMedia)
            return;
        root.screenState.dashboardTab = Config.dashboard.showDashboard ? 1 : 0;
        root.screenState.dashboard = true;
    }

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.small

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
                onTapped: root.openMediaTab()
            }

            Row {
                id: infoRow

                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.spacing.small

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: root.artSize
                    implicitHeight: root.artSize

                    // Dimmed note when idle or without art
                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "music_note"
                        color: root.hasTrack ? Colours.palette.m3primary : Colours.palette.m3outline
                        fill: 1
                        fontStyle: Tokens.font.icon.small
                        opacity: root.hasTrack && cover.status === Image.Ready ? 0 : (root.hasTrack ? 1 : 0.6)

                        Behavior on opacity {
                            Anim {
                                type: Anim.DefaultEffects
                            }
                        }
                    }

                    StyledClippingRect {
                        anchors.fill: parent
                        radius: Tokens.rounding.small
                        color: "transparent"
                        opacity: root.hasTrack ? 1 : 0

                        Behavior on opacity {
                            Anim {
                                type: Anim.DefaultEffects
                            }
                        }

                        // Fades out and back in when the song changes
                        FadeImage {
                            id: cover

                            anchors.fill: parent
                            source: root.hasTrack ? Players.getArtUrl(root.player) : ""
                        }
                    }
                }

                Item {
                    id: textBox

                    readonly property bool overflowing: full.implicitWidth > width + 1
                    readonly property bool scrolling: overflowing && infoHover.hovered

                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: root.hasTrack ? Math.min(full.implicitWidth, root.textCap) : idleText.implicitWidth
                    implicitHeight: root.borderHeight
                    clip: true

                    Behavior on implicitWidth {
                        Anim {
                            type: Anim.FastSpatial
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
                            Anim {
                                type: Anim.DefaultEffects
                            }
                        }
                    }

                    // Elided at rest
                    Row {
                        id: elided

                        anchors.verticalCenter: parent.verticalCenter
                        opacity: root.hasTrack && !textBox.scrolling ? 1 : 0

                        Behavior on opacity {
                            Anim {
                                type: Anim.DefaultEffects
                            }
                        }

                        TitleText {
                            id: titleText

                            width: Math.min(implicitWidth, textBox.width - (artistText.text ? Math.min(artistText.implicitWidth, textBox.width * 0.4) + sep.implicitWidth : 0))
                            elide: Text.ElideRight
                        }

                        SepText {
                            id: sep

                            visible: !!artistText.text
                        }

                        ArtistText {
                            id: artistText

                            width: Math.max(0, Math.min(implicitWidth, textBox.width - titleText.width - sep.implicitWidth))
                            elide: Text.ElideRight
                        }
                    }

                    // Full text, scrolled slowly while hovered if it doesn't fit
                    Row {
                        id: full

                        property real offset

                        anchors.verticalCenter: parent.verticalCenter
                        x: -offset
                        opacity: root.hasTrack && textBox.scrolling ? 1 : 0

                        Behavior on opacity {
                            Anim {
                                type: Anim.DefaultEffects
                            }
                        }

                        TitleText {}

                        SepText {
                            visible: !!root.player?.trackArtist
                        }

                        ArtistText {}

                        SequentialAnimation {
                            running: textBox.scrolling
                            loops: Animation.Infinite
                            onStopped: full.offset = 0

                            PauseAnimation {
                                duration: 900
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

        Row {
            anchors.verticalCenter: parent.verticalCenter

            MediaButton {
                icon: "skip_previous"
                disabled: !root.hasTrack || !root.player?.canGoPrevious
                onClicked: root.player?.previous()
            }

            MediaButton {
                icon: root.player?.isPlaying ? "pause" : "play_arrow"
                disabled: !root.hasTrack || !root.player?.canTogglePlaying
                onClicked: root.player?.togglePlaying()
            }

            MediaButton {
                icon: "skip_next"
                disabled: !root.hasTrack || !root.player?.canGoNext
                onClicked: root.player?.next()
            }
        }
    }

    component TitleText: StyledText {
        anchors.verticalCenter: parent?.verticalCenter
        animate: true
        text: root.player?.trackTitle || Tr.tr("Unknown title")
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
        animate: true
        text: root.player?.trackArtist ?? ""
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.medium
    }

    component MediaButton: Item {
        id: button

        property alias icon: iconItem.text
        property bool disabled

        signal clicked

        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: root.buttonSize
        implicitHeight: root.buttonSize
        opacity: disabled ? 0.38 : 1

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
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
            opacity: tap.pressed ? 0.2 : hover.hovered ? 0.12 : 0
            scale: tap.pressed ? 0.88 : 1

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            Behavior on scale {
                Anim {
                    type: Anim.FastSpatial
                }
            }
        }

        MaterialIcon {
            id: iconItem

            anchors.centerIn: parent
            animate: true
            color: hover.hovered ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            fill: 1
            fontStyle: Tokens.font.icon.medium
        }
    }
}
