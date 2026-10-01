import "notes"
import QtQuick
import QtQuick.Layouts
import Caelestia.Config

Item {
    id: root

    implicitWidth: 840 // Same as the weather tab, so the window keeps the dashboard tab's width
    implicitHeight: Tokens.sizes.dashboard.mediaTabHeight

    RowLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.medium

        NoteList {
            Layout.preferredWidth: (root.width - parent.spacing) / 2
            Layout.fillHeight: true
        }

        TodoList {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
