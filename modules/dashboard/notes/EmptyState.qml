import QtQuick
import QtQuick.Layouts
import M3Shapes
import Caelestia.Config
import qs.components
import qs.services

ColumnLayout {
    id: root

    required property string icon
    required property string title
    required property string subtitle
    property int shape: MaterialShape.Cookie7Sided

    spacing: Tokens.spacing.small
    visible: opacity > 0

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    MaterialShape {
        Layout.alignment: Qt.AlignHCenter
        Layout.bottomMargin: Tokens.spacing.small
        color: Colours.palette.m3primaryContainer
        implicitSize: icon.implicitHeight + Tokens.padding.large * 2
        shape: root.shape

        Behavior on color {
            CAnim {}
        }

        MaterialIcon {
            id: icon

            anchors.centerIn: parent
            text: root.icon
            fontStyle: Tokens.font.icon.large
            color: Colours.palette.m3onPrimaryContainer
        }
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        text: root.title
        font: Tokens.font.title.medium
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        text: root.subtitle
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.medium
    }
}
