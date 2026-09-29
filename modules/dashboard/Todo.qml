pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    property var todos: []

    function save(): void {
        todos = todos.slice(); // Reassign to trigger bindings
        storage.setText(JSON.stringify(todos, null, 2));
    }

    function add(): void {
        const text = input.text.trim();
        if (!text)
            return;
        todos.push({
            text,
            done: false
        });
        input.text = "";
        save();
    }

    implicitWidth: 420
    implicitHeight: layout.implicitHeight

    FileView {
        id: storage

        printErrors: false
        path: `${Paths.state}/todos.json`
        onLoaded: {
            try {
                root.todos = JSON.parse(text());
            } catch (e) {
                root.todos = [];
            }
        }
    }

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledTextField {
                id: input

                Layout.fillWidth: true
                verticalPadding: Tokens.padding.small
                placeholderText: Tr.tr("New task")
                leadingIcon: "add_task"
                onAccepted: root.add()
            }

            IconButton {
                icon: "add"
                isRound: true
                onClicked: root.add()
            }
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: Math.min(list.contentHeight, 360) + Tokens.padding.small * 2
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer

            StyledText {
                anchors.centerIn: parent
                visible: root.todos.length === 0
                text: Tr.tr("No tasks yet")
                color: Colours.palette.m3onSurfaceVariant
            }

            StyledListView {
                id: list

                anchors.fill: parent
                anchors.margins: Tokens.padding.small
                clip: true
                model: root.todos
                spacing: Tokens.spacing.extraSmall

                delegate: RowLayout {
                    id: todo

                    required property var modelData
                    required property int index

                    width: list.width
                    spacing: Tokens.spacing.small

                    IconButton {
                        icon: todo.modelData.done ? "check_box" : "check_box_outline_blank"
                        type: IconButton.Text
                        isRound: true
                        onClicked: {
                            root.todos[todo.index].done = !todo.modelData.done;
                            root.save();
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: todo.modelData.text
                        elide: Text.ElideRight
                        font.strikeout: todo.modelData.done
                        color: todo.modelData.done ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
                    }

                    IconButton {
                        icon: "delete"
                        type: IconButton.Text
                        isRound: true
                        onClicked: {
                            root.todos.splice(todo.index, 1);
                            root.save();
                        }
                    }
                }
            }
        }
    }
}
