pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components
import qs.modules.bar.popouts // Need to import this module so the Wrapper type is the same as others

Item {
    id: root

    required property ShellScreen screen

    readonly property alias content: content
    // The left bar is disabled, so popouts hang from the top border under the hovered icon.
    // currentCenter is the icon's x in window coordinates; leftOffset is the left border width.
    property real leftOffset
    property real offsetScale: content.isDetached || content.hasCurrent ? 0 : 1

    visible: width > 0 && height > 0
    clip: true

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight * (1 - offsetScale)

    x: {
        if (content.isDetached)
            return (parent.width - content.nonAnimWidth) / 2;

        const off = content.currentCenter - leftOffset - content.nonAnimWidth / 2;
        return Math.max(0, Math.min(off, parent.width - content.nonAnimWidth));
    }
    y: content.isDetached ? (parent.height - content.nonAnimHeight) / 2 : 0

    Behavior on offsetScale {
        Anim {}
    }

    Behavior on x {
        enabled: root.offsetScale < 1

        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Behavior on y {
        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Wrapper {
        id: content

        screen: root.screen
        offsetScale: root.offsetScale

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
    }
}
