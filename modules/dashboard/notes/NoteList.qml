pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
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
    property int editIndex: -1
    property bool populating

    function save(): void {
        if (!loaded)
            return;
        const data = [];
        for (let i = 0; i < notes.count; i++) {
            const note = notes.get(i);
            data.push({
                title: note.title,
                text: note.text
            });
        }
        storage.setText(JSON.stringify(data, null, 2));
    }

    function open(index: int): void {
        populating = true;
        titleField.text = notes.get(index).title;
        body.text = notes.get(index).text;
        populating = false;
        editIndex = index;
    }

    function create(): void {
        notes.insert(0, {
            title: "",
            text: ""
        });
        open(0);
        titleField.forceActiveFocus();
    }

    function close(): void {
        const note = notes.get(editIndex);
        if (note && !note.title.trim() && !note.text.trim())
            notes.remove(editIndex);
        editIndex = -1;
        save();
    }

    function remove(): void {
        notes.remove(editIndex);
        editIndex = -1;
        save();
    }

    function update(prop: string, value: string): void {
        if (populating || editIndex < 0)
            return;
        notes.setProperty(editIndex, prop, value);
        save();
    }

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.extraLarge

    ListModel {
        id: notes
    }

    FileView {
        id: storage

        printErrors: false
        path: `${Paths.state}/notes.json`
        onLoaded: {
            if (root.loaded)
                return;
            try {
                for (const note of JSON.parse(text()))
                    notes.append({
                        title: String(note.title ?? ""),
                        text: String(note.text ?? "")
                    });
            } catch (e) {
                console.warn("Failed to parse notes:", e);
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
            icon: root.editIndex < 0 ? "sticky_note_2" : "edit_note"
            title: root.editIndex < 0 ? Tr.tr("Notes") : Tr.tr("Edit note")
            badge: root.editIndex < 0 && notes.count ? notes.count : ""

            IconButton {
                icon: root.editIndex < 0 ? "add" : "arrow_back"
                isRound: true
                onClicked: root.editIndex < 0 ? root.create() : root.close()
            }
        }

        Item {
            id: content

            Layout.fillWidth: true
            Layout.fillHeight: true

            state: root.editIndex < 0 ? "" : "editing"

            states: State {
                name: "editing"

                PropertyChanges {
                    listPage.opacity: 0
                    editor.opacity: 1
                }
            }

            transitions: [
                Transition {
                    from: ""

                    SequentialAnimation {
                        Anim {
                            target: listPage
                            property: "opacity"
                            type: Anim.FastEffects
                        }
                        Anim {
                            target: editor
                            property: "opacity"
                            type: Anim.DefaultEffects
                        }
                    }
                },
                Transition {
                    to: ""

                    SequentialAnimation {
                        Anim {
                            target: editor
                            property: "opacity"
                            type: Anim.FastEffects
                        }
                        Anim {
                            target: listPage
                            property: "opacity"
                            type: Anim.DefaultEffects
                        }
                    }
                }
            ]

            Item {
                id: listPage

                anchors.fill: parent
                visible: opacity > 0
                clip: true

                EmptyState {
                    anchors.centerIn: parent
                    opacity: notes.count ? 0 : 1
                    icon: "sticky_note_2"
                    title: Tr.tr("No notes yet")
                    subtitle: Tr.tr("Jot something down with the + button")
                    shape: MaterialShape.Cookie6Sided
                }

                VerticalFadeListView {
                    id: list

                    anchors.fill: parent
                    clip: true
                    spacing: Tokens.spacing.small
                    model: notes
                    flickDeceleration: 1000
                    maximumFlickVelocity: 7000

                    NotesWheelScroll {
                        flickable: list
                        step: Math.max(list.count ? (list.contentHeight + list.spacing) / list.count : 0, 60)
                    }

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
                        id: note

                        required property int index
                        required property string title
                        required property string text

                        width: list.width
                        implicitHeight: noteLayout.implicitHeight + Tokens.padding.large * 2
                        radius: Tokens.rounding.large
                        color: Colours.tPalette.m3surfaceContainerHigh

                        StateLayer {
                            radius: note.radius
                            onClicked: root.open(note.index)
                        }

                        ColumnLayout {
                            id: noteLayout

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Tokens.padding.large
                            spacing: Tokens.spacing.extraSmall

                            StyledText {
                                Layout.fillWidth: true
                                text: note.title.trim() || Tr.tr("Untitled")
                                color: note.title.trim() ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.title.small
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: !!note.text.trim()
                                text: note.text.trim()
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.body.medium
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                id: editor

                anchors.fill: parent
                spacing: Tokens.spacing.medium
                visible: opacity > 0
                opacity: 0

                StyledRect {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Tokens.rounding.large
                    color: Colours.tPalette.m3surfaceContainerHigh

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.large
                        spacing: Tokens.spacing.small

                        TextFieldBase {
                            id: titleField

                            Layout.fillWidth: true
                            font: Tokens.font.title.large
                            onTextChanged: root.update("title", text)
                            onAccepted: body.forceActiveFocus()

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !parent.text
                                text: Tr.tr("Title")
                                color: Colours.palette.m3onSurfaceVariant
                                font: parent.font
                            }
                        }

                        StyledRect {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: Colours.palette.m3outlineVariant
                        }

                        StyledFlickable {
                            id: bodyFlick

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            flickableDirection: Flickable.VerticalFlick
                            flickDeceleration: 1000
                            maximumFlickVelocity: 7000

                            NotesWheelScroll {
                                flickable: bodyFlick
                                step: Math.max(body.cursorRectangle.height, 16) * 3 // ~3 lines
                            }

                            T.TextArea.flickable: T.TextArea {
                                id: body

                                color: Colours.palette.m3onSurface
                                selectionColor: Qt.alpha(Colours.palette.m3primary, 0.4)
                                selectedTextColor: color
                                font: Tokens.font.body.medium
                                wrapMode: TextEdit.Wrap
                                renderType: Text.NativeRendering
                                onTextChanged: root.update("text", text)

                                cursorDelegate: StyledRect {
                                    implicitWidth: 1.5
                                    color: Colours.palette.m3primary
                                    radius: Tokens.rounding.large
                                }

                                StyledText {
                                    visible: !parent.text
                                    text: Tr.tr("Write something...")
                                    color: Colours.palette.m3onSurfaceVariant
                                    font: parent.font
                                }
                            }

                            StyledScrollBar.vertical: StyledScrollBar {
                                flickable: bodyFlick
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    IconTextButton {
                        type: IconTextButton.Text
                        icon: "delete"
                        text: Tr.tr("Delete")
                        inactiveOnColour: Colours.palette.m3error
                        onClicked: root.remove()
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    IconTextButton {
                        type: IconTextButton.Filled
                        icon: "check"
                        text: Tr.tr("Done")
                        onClicked: root.close()
                    }
                }
            }
        }
    }
}
