import "notes"
import QtQuick
import QtQuick.Layouts
import Caelestia.Config

Item {
    id: root

    implicitWidth: Tokens.sizes.dashboard.mediaTabWidth
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
