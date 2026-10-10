pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services
import qs.utils
import qs.modules.bar.components.status
import qs.modules.bar.popouts as BarPopouts

// Left side of the top border, replacing the old left bar:
// [power] [workspace dots] [tray icons] [network · bluetooth · battery].
// Hovering an icon opens its popout (same popouts as the bar, hanging down from the top border);
// Interactions closes it once the cursor leaves both the icons and the popout.
Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property int borderHeight
    property real shownOpacity: 1
    property real startupProgress: 0

    readonly property int pillHeight: borderHeight - 6
    readonly property int iconSize: borderHeight - 8
    readonly property int fast: 150 // Hover

    readonly property HyprlandMonitor monitor: Hypr.monitorFor(screen)
    readonly property int activeWsId: monitor?.activeWorkspace?.id ?? 1
    readonly property bool onSpecial: (monitor?.lastIpcObject.specialWorkspace?.name ?? "") !== ""

    // Workspaces 1..n, n covering the configured count, the active one and every occupied one
    readonly property var occupied: {
        const perMonitor = Config.bar.workspaces.perMonitor;
        return Hypr.workspaces.values.filter(w => w.id > 0 && (!perMonitor || w.monitor === root.monitor) && w.toplevels.values.length > 0).map(w => w.id);
    }
    readonly property int wsCount: Math.max(Config.bar.workspaces.shown, activeWsId, ...occupied)

    readonly property var trayValues: SystemTray.items.values.filter(i => i.status !== Status.Passive && !GlobalConfig.bar.tray.hiddenIcons.includes(i.id))

    readonly property alias hovered: barHover.hovered

    // Supplied by ContentWindow: whether the cursor is over the open popout
    property var popoutHovered: () => false

    // A tray menu with an open submenu stays open until clicked away, like with the bar
    readonly property bool menuPinned: popouts.currentName.startsWith("traymenu") && ((popouts.current as StackView)?.depth ?? 0) > 1

    function hoverPopout(item: Item): void {
        if (menuPinned)
            return;
        const allowed = item?.popoutName && (item.popoutName.startsWith("traymenu") ? Config.bar.popouts.tray : Config.bar.popouts.statusIcons);
        if (allowed)
            openPopout(item);
        else
            popouts.hasCurrent = false;
    }

    function openPopout(item: Item): void {
        popouts.currentName = item.popoutName;
        popouts.currentCenter = Qt.binding(() => item.mapToItem(null, item.width / 2, 0).x);
        popouts.hasCurrent = true;
    }

    implicitWidth: row.implicitWidth
    implicitHeight: borderHeight
    opacity: shownOpacity * startupProgress
    visible: opacity > 0

    // Leaving the icons: close the popout unless the cursor went down into it
    HoverHandler {
        id: barHover

        blocking: false
        onHoveredChanged: {
            if (!hovered)
                closeTimer.restart();
        }
    }

    Timer {
        id: closeTimer

        interval: 120
        onTriggered: {
            if (!barHover.hovered && !root.menuPinned && !root.popoutHovered())
                root.popouts.hasCurrent = false;
        }
    }

    // Smooth fade-in when the shell starts
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

        // Power, opens the session menu
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: root.pillHeight
            hoverColour: Colours.palette.m3error
            onClicked: root.screenState.session = !root.screenState.session

            MaterialIcon {
                anchors.centerIn: parent
                text: "power_settings_new"
                color: Colours.palette.m3error
                fontStyle: Tokens.font.icon.builders.small.weight(Font.Bold).build()
            }
        }

        // Workspaces
        StyledRect {
            id: wsPill

            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: wsRow.implicitWidth + Tokens.padding.small * 2
            implicitHeight: root.pillHeight
            radius: Tokens.rounding.full
            color: Colours.tPalette.m3surfaceContainer

            Row {
                id: wsRow

                anchors.centerIn: parent
                opacity: root.onSpecial ? 0.5 : 1

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                Repeater {
                    model: root.wsCount

                    Item {
                        id: ws

                        required property int index
                        readonly property int wsId: index + 1
                        readonly property bool active: wsId === root.activeWsId
                        readonly property bool isOccupied: root.occupied.includes(wsId)

                        implicitWidth: dot.width + Tokens.padding.small * 2
                        implicitHeight: root.pillHeight

                        HoverHandler {
                            id: wsHover

                            blocking: false
                            cursorShape: Qt.PointingHandCursor
                            onHoveredChanged: {
                                if (hovered)
                                    root.hoverPopout(null);
                            }
                        }

                        TapHandler {
                            onTapped: {
                                if (Hypr.activeWsId !== ws.wsId)
                                    Hypr.focusWorkspace(ws.wsId);
                                else
                                    Hypr.toggleSpecial("special");
                            }
                        }

                        StyledRect {
                            id: dot

                            anchors.centerIn: parent
                            implicitWidth: ws.active ? 18 : 7
                            implicitHeight: 7
                            radius: Tokens.rounding.full
                            scale: wsHover.hovered && !ws.active ? 1.3 : 1
                            color: {
                                if (ws.active)
                                    return Colours.palette.m3primary;
                                if (wsHover.hovered)
                                    return Colours.palette.m3onSurface;
                                if (ws.isOccupied)
                                    return Colours.palette.m3onSurfaceVariant;
                                return Colours.palette.m3outlineVariant;
                            }

                            Behavior on implicitWidth {
                                Anim {}
                            }

                            Behavior on scale {
                                Anim {
                                    type: Anim.DefaultEffects
                                }
                            }
                        }
                    }
                }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    if (!Config.bar.scrollActions.workspaces)
                        return;
                    const specialWs = root.monitor?.lastIpcObject.specialWorkspace.name;
                    if (specialWs?.length > 0)
                        Hypr.toggleSpecial(specialWs.slice(8));
                    else if (event.angleDelta.y < 0 || root.activeWsId > 1)
                        Hypr.focusWorkspace(`r${event.angleDelta.y > 0 ? "-" : "+"}1`);
                }
            }
        }

        // System tray
        StyledRect {
            anchors.verticalCenter: parent.verticalCenter
            visible: trayRepeater.count > 0
            implicitWidth: trayRow.implicitWidth + (Config.bar.tray.background ? Tokens.padding.small * 2 : 0)
            implicitHeight: root.pillHeight
            radius: Tokens.rounding.full
            color: Config.bar.tray.background ? Colours.tPalette.m3surfaceContainer : "transparent"

            Row {
                id: trayRow

                anchors.centerIn: parent
                spacing: Tokens.spacing.extraSmall

                add: Transition {
                    Anim {
                        properties: "scale"
                        from: 0
                        to: 1
                        easing: Tokens.anim.standardDecel
                    }
                }

                move: Transition {
                    Anim {
                        properties: "scale"
                        to: 1
                        easing: Tokens.anim.standardDecel
                    }
                    Anim {
                        properties: "x,y"
                    }
                }

                Repeater {
                    id: trayRepeater

                    model: ScriptModel {
                        values: root.trayValues
                    }

                    IconButton {
                        id: trayItem

                        required property SystemTrayItem modelData
                        required property int index

                        popoutName: modelData.hasMenu ? `traymenu${index}` : ""
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: button => {
                            if (button === Qt.LeftButton)
                                modelData.activate();
                            else
                                modelData.secondaryActivate();
                        }

                        ColouredIcon {
                            anchors.centerIn: parent
                            implicitWidth: root.iconSize - 4
                            implicitHeight: root.iconSize - 4
                            source: Icons.getTrayIcon(trayItem.modelData.id, trayItem.modelData.icon)
                            colour: Colours.palette.m3secondary
                            layer.enabled: Config.bar.tray.recolour
                        }
                    }
                }
            }
        }

        // Network, bluetooth, battery
        StyledRect {
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: statusRow.implicitWidth + Tokens.padding.small * 2
            implicitHeight: root.pillHeight
            radius: Tokens.rounding.full
            color: Colours.tPalette.m3surfaceContainer

            Row {
                id: statusRow

                anchors.centerIn: parent

                IconButton {
                    id: networkIcon

                    popoutName: "network"
                    onClicked: root.openPopout(this)

                    MaterialIcon {
                        anchors.centerIn: parent
                        animate: true
                        text: Nmcli.activeEthernet ? "cable" : Nmcli.active ? Icons.getNetworkIcon(Nmcli.active.strength ?? 0) : "wifi_off"
                        color: Colours.palette.m3secondary
                        fontStyle: Tokens.font.icon.small
                    }
                }

                IconButton {
                    id: bluetoothIcon

                    popoutName: "bluetooth"
                    implicitWidth: btRow.implicitWidth + 6
                    onClicked: root.openPopout(this)

                    Row {
                        id: btRow

                        anchors.centerIn: parent
                        spacing: Tokens.spacing.extraSmall

                        MaterialIcon {
                            animate: true
                            text: {
                                if (!Bluetooth.defaultAdapter?.enabled) // qmllint disable unresolved-type
                                    return "bluetooth_disabled";
                                if (Bluetooth.devices.values.some(d => d.connected)) // qmllint disable unresolved-type
                                    return "bluetooth_connected";
                                return "bluetooth";
                            }
                            color: Colours.palette.m3secondary
                            fontStyle: Tokens.font.icon.small
                        }

                        // Connected bluetooth devices
                        Repeater {
                            model: ScriptModel {
                                values: Bluetooth.devices.values.filter(d => d.state !== BluetoothDeviceState.Disconnected) // qmllint disable unresolved-type
                            }

                            MaterialIcon {
                                id: device

                                required property BluetoothDevice modelData

                                animate: true
                                text: Icons.getBluetoothIcon(modelData?.icon)
                                color: Colours.palette.m3secondary
                                fill: 1
                                fontStyle: Tokens.font.icon.small

                                SequentialAnimation on opacity {
                                    running: device.modelData?.state !== BluetoothDeviceState.Connected // qmllint disable unresolved-type
                                    alwaysRunToEnd: true
                                    loops: Animation.Infinite

                                    Anim {
                                        from: 1
                                        to: 0
                                        duration: Tokens.anim.durations.large
                                        easing: Tokens.anim.standardAccel
                                    }
                                    Anim {
                                        from: 0
                                        to: 1
                                        duration: Tokens.anim.durations.large
                                        easing: Tokens.anim.standardDecel
                                    }
                                }
                            }
                        }
                    }
                }

                IconButton {
                    id: batteryIcon

                    popoutName: "battery"
                    onClicked: root.openPopout(this)

                    BatteryStatus {
                        anchors.centerIn: parent
                        colour: Colours.palette.m3secondary
                        fontStyle: Tokens.font.icon.small
                    }
                }
            }
        }
    }

    // Round hover/press highlight, same feel as the music buttons on the right
    component IconButton: Item {
        id: button

        property string popoutName
        property color hoverColour: Colours.palette.m3primary
        property alias acceptedButtons: tap.acceptedButtons

        signal clicked(button: int)

        anchors.verticalCenter: parent?.verticalCenter
        implicitWidth: root.iconSize + 4
        implicitHeight: root.pillHeight

        HoverHandler {
            id: hover

            blocking: false
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: {
                if (hovered)
                    root.hoverPopout(button);
            }
        }

        TapHandler {
            id: tap

            onTapped: (eventPoint, btn) => button.clicked(btn)
        }

        StyledRect {
            anchors.centerIn: parent
            implicitWidth: parent.width
            implicitHeight: root.pillHeight - 2
            radius: Tokens.rounding.full
            color: button.hoverColour
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
    }
}
