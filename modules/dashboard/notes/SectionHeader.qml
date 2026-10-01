import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

RowLayout {
    id: root

    required property string icon
    required property string title
    property string badge

    spacing: Tokens.spacing.medium

    MaterialIcon {
        Layout.topMargin: Math.round(fontInfo.pointSize * 0.12)
        text: root.icon
        fontStyle: Tokens.font.icon.medium
    }

    StyledText {
        Layout.fillWidth: true
        text: root.title
        font: Tokens.font.title.medium
        elide: Text.ElideRight
    }

    StyledRect {
        visible: !!root.badge
        radius: Tokens.rounding.full
        color: Colours.palette.m3secondaryContainer
        implicitWidth: badgeText.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: badgeText.implicitHeight + Tokens.padding.extraSmall * 2

        StyledText {
            id: badgeText

            anchors.centerIn: parent
            text: root.badge
            color: Colours.palette.m3onSecondaryContainer
            font: Tokens.font.label.medium
        }
    }
}
