pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import M3Shapes
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.utils

StyledRect {
    id: root

    property bool loaded
    property int doneCount

    function save(): void {
        const data = [];
        let done = 0;
        for (let i = 0; i < todos.count; i++) {
            const todo = todos.get(i);
            data.push({
                text: todo.text,
                done: todo.done
            });
            if (todo.done)
                done++;
        }
        doneCount = done;
        if (loaded)
            storage.setText(JSON.stringify(data, null, 2));
    }

    function add(): void {
        const text = input.text.trim();
        if (!text)
            return;
        todos.append({
            text,
            done: false
        });
        input.text = "";
        save();
    }

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.extraLarge

    ListModel {
        id: todos
    }

    FileView {
        id: storage

        printErrors: false
        path: `${Paths.state}/todos.json`
        onLoaded: {
            if (root.loaded)
                return;
            try {
                for (const todo of JSON.parse(text())) {
                    todos.append({
                        text: String(todo.text ?? ""),
                        done: !!todo.done
                    });
                    if (todo.done)
                        root.doneCount++;
                }
            } catch (e) {
                console.warn("Failed to parse todos:", e);
                return; // Don't overwrite a file we couldn't read
            }
            root.loaded = true;
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                root.loaded = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        SectionHeader {
            Layout.fillWidth: true
            icon: "checklist"
            title: Tr.tr("Todo")
            badge: todos.count ? `${root.doneCount}/${todos.count}` : ""

            IconButton {
                icon: "delete_sweep"
                type: IconButton.Tonal
                isRound: true
                disabled: !root.doneCount
                onClicked: {
                    for (let i = todos.count - 1; i >= 0; i--)
                        if (todos.get(i).done)
                            todos.remove(i);
                    root.save();
                }
            }
        }

        StyledProgressBar {
            Layout.fillWidth: true
            visible: todos.count > 0
            implicitHeight: Tokens.padding.small
            value: todos.count ? root.doneCount / todos.count : 0

            Behavior on value {
                Anim {}
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledTextField {
                id: input

                Layout.fillWidth: true
                verticalPadding: Tokens.padding.small
                radius: Tokens.rounding.full
                placeholderText: Tr.tr("Add a task")
                onAccepted: root.add()
            }

            IconButton {
                icon: "add"
                isRound: true
                disabled: !input.text.trim()
                onClicked: root.add()
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            EmptyState {
                anchors.centerIn: parent
                opacity: todos.count ? 0 : 1
                icon: "task_alt"
                title: Tr.tr("All clear")
                subtitle: Tr.tr("Add a task to get started")
                shape: MaterialShape.Cookie9Sided
            }

            VerticalFadeListView {
                id: list

                anchors.fill: parent
                clip: true
                spacing: Tokens.spacing.small
                model: todos

                add: Transition {
                    Anim {
                        type: Anim.DefaultEffects
                        property: "opacity"
                        from: 0
                        to: 1
                    }
                    Anim {
                        property: "scale"
                        from: 0.8
                        to: 1
                    }
                }

                remove: Transition {
                    Anim {
                        type: Anim.DefaultEffects
                        property: "opacity"
                        to: 0
                    }
                    Anim {
                        property: "scale"
                        to: 0.8
                    }
                }

                displaced: Transition {
                    Anim {
                        property: "y"
                    }
                    Anim {
                        type: Anim.DefaultEffects
                        properties: "opacity,scale"
                        to: 1
                    }
                }

                delegate: StyledRect {
                    id: todo

                    required property int index
                    required property string text
                    required property bool done

                    width: list.width
                    implicitHeight: row.implicitHeight + Tokens.padding.small * 2
                    radius: Tokens.rounding.full
                    color: todo.done ? Colours.tPalette.m3surfaceContainerLow : Colours.tPalette.m3surfaceContainerHigh

                    StateLayer {
                        radius: todo.radius
                        onClicked: {
                            todos.setProperty(todo.index, "done", !todo.done);
                            root.save();
                        }
                    }

                    RowLayout {
                        id: row

                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.medium
                        anchors.rightMargin: Tokens.padding.small
                        spacing: Tokens.spacing.medium

                        MaterialIcon {
                            text: todo.done ? "check_circle" : "radio_button_unchecked"
                            color: todo.done ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.medium
                            fill: todo.done ? 1 : 0

                            Behavior on fill {
                                Anim {
                                    type: Anim.DefaultEffects
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: todo.text
                            elide: Text.ElideRight
                            color: todo.done ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
                            font: {
                                const f = Qt.font(Tokens.font.body.medium);
                                f.strikeout = todo.done;
                                return f;
                            }
                        }

                        IconButton {
                            icon: "close"
                            type: IconButton.Text
                            isRound: true
                            font: Tokens.font.icon.small
                            onClicked: {
                                todos.remove(todo.index);
                                root.save();
                            }
                        }
                    }
                }
            }
        }
    }
}
