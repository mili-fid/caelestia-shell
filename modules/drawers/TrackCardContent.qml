pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

// Track card contents: a cover slot on the left, title and artist beside it. Under the border the cover slot is
// left empty, since the flying cover (TrackCard) lands in it; the fullscreen pill draws the cover itself.
// The text slides in with `reveal` and cross-fades in place when the track changes while the card is out.
Item {
    id: root

    required property string title
    required property string artist
    required property string artUrl
    property bool showCover
    property real reveal: 1 // 0..1: text slid in

    readonly property int artSize: 72
    readonly property int pad: 12
    readonly property real coverX: pad
    readonly property real coverY: Math.round((height - artSize) / 2)

    // What is on screen; swapped by a quick fade so skips don't snap
    property string shownTitle: title
    property string shownArtist: artist
    property real swapOpacity: 1

    onTitleChanged: swapAnim.restart()
    onArtistChanged: swapAnim.restart()

    SequentialAnimation {
        id: swapAnim

        NumberAnimation {
            target: root
            property: "swapOpacity"
            to: 0
            duration: 80
        }
        ScriptAction {
            script: {
                root.shownTitle = root.title;
                root.shownArtist = root.artist;
            }
        }
        NumberAnimation {
            target: root
            property: "swapOpacity"
            to: 1
            duration: 140
        }
    }

    Loader {
        x: root.coverX
        y: root.coverY
        active: root.showCover

        sourceComponent: TrackCover {
            width: root.artSize
            height: root.artSize
            artUrl: root.artUrl
        }
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.pad + root.artSize + Tokens.spacing.large
        anchors.rightMargin: Tokens.padding.large + Tokens.padding.small
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -10 * (1 - root.reveal) // Slides down into place, with the drip
        opacity: root.reveal * root.swapOpacity
        spacing: 2

        StyledText {
            width: parent.width
            text: root.shownTitle || Tr.tr("Unknown title")
            elide: Text.ElideRight
            color: Colours.palette.m3onSurface
            font: Tokens.font.body.builders.large.weight(Font.Medium).build()
        }

        StyledText {
            width: parent.width
            visible: !!root.shownArtist
            text: root.shownArtist
            elide: Text.ElideRight
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.medium
        }
    }
}
