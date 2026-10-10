import "notes"
import QtQuick
import Caelestia.Config

Item {
    id: root

    implicitWidth: 840 // Same as the weather tab, so the window keeps the dashboard tab's width
    implicitHeight: Tokens.sizes.dashboard.mediaTabHeight

    NoteList {
        anchors.fill: parent
    }
}
