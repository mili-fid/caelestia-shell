pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Track card cover: a note placeholder until the art loads, then the art cross-fades in. A new cover loads in
// the hidden image and cross-fades over the old one once ready, so skipping never blanks it.
Item {
    id: root

    required property string artUrl
    property real radius: Tokens.rounding.medium
    property int loadSize: 144 // Decoded size; the cover is drawn from thumbnail size up to the card's

    readonly property int swap: 180

    onArtUrlChanged: load(artUrl)
    Component.onCompleted: load(artUrl)

    function load(url: string): void {
        if (url === front.source.toString())
            return;
        back.source = url;
        if (url === "" || back.status === Image.Ready)
            frontA = !frontA;
    }

    property bool frontA: true
    readonly property Image front: frontA ? imgA : imgB
    readonly property Image back: frontA ? imgB : imgA
    readonly property bool hasArt: front.status === Image.Ready && front.source.toString() !== ""

    StyledRect {
        anchors.fill: parent
        radius: root.radius
        color: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
        opacity: root.hasArt ? 0 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: root.swap
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: "music_note"
            color: Colours.palette.m3primary
            fill: 1
            fontStyle: Tokens.font.icon.size(Math.max(1, Math.round(root.width * 0.4))).build()
        }
    }

    StyledClippingRect {
        anchors.fill: parent
        radius: root.radius

        CoverImage {
            id: imgA

            shown: root.frontA
        }

        CoverImage {
            id: imgB

            shown: !root.frontA
        }
    }

    component CoverImage: Image {
        id: img

        property bool shown

        anchors.fill: parent
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.loadSize, root.loadSize)
        opacity: shown && status === Image.Ready ? 1 : 0

        // Bring the freshly loaded cover to the front (or the note, if it failed)
        onStatusChanged: {
            if ((status === Image.Ready || status === Image.Error) && !shown && img === root.back && source.toString() === root.artUrl)
                root.frontA = !root.frontA;
        }

        Behavior on opacity {
            NumberAnimation {
                duration: root.swap
            }
        }
    }
}
