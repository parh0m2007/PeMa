import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Goals list component — shown inside Analytics tab
Item {
    id: goalsList

    // Theme (inject from root)
    property color surface:     "#ffffff"
    property color surface2:    "#f6f8fa"
    property color borderCol:   "#dde3eb"
    property color textPrimary: "#0d1117"
    property color textMuted:   "#57606a"
    property color accent:      "#6366f1"
    property color runColor:    "#22c55e"
    property color hardColor:   "#ef4444"
    property bool  dark: false

    property var goalsModel: []

    signal deleteRequested(string id)
    signal addRequested()

    implicitHeight: goalsCol.implicitHeight

    Column {
        id: goalsCol
        anchors { left: parent.left; right: parent.right }
        spacing: 8

        Repeater {
            model: goalsList.goalsModel
            delegate: Rectangle {
                width: goalsCol.width; height: goalRow.implicitHeight + 20
                radius: 12; color: goalsList.surface
                border.width: 1; border.color: goalsList.borderCol

                // Left accent bar
                Rectangle {
                    width: 4; height: parent.height; radius: 3
                    color: {
                        var dl = modelData.daysLeft || 0
                        if (dl < 0)   return goalsList.textMuted
                        if (dl < 30)  return goalsList.hardColor
                        if (dl < 90)  return "#f59e0b"
                        return goalsList.runColor
                    }
                }

                ColumnLayout {
                    id: goalRow
                    anchors { left: parent.left; right: parent.right; leftMargin: 16; rightMargin: 12; top: parent.top; topMargin: 10 }
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Label {
                            text: "🎯 " + (modelData.title || "")
                            font.pixelSize: 13; font.weight: Font.DemiBold
                            color: goalsList.textPrimary
                            Layout.fillWidth: true; elide: Text.ElideRight
                        }
                        Label {
                            text: {
                                var dl = modelData.daysLeft || 0
                                if (dl < 0) return "завершено"
                                return dl + " дн."
                            }
                            font.pixelSize: 11; color: goalsList.textMuted
                        }
                        RoundButton {
                            width: 22; height: 22; radius: 6; flat: true
                            text: "×"; font.pixelSize: 13
                            onClicked: goalsList.deleteRequested(modelData.id)
                        }
                    }

                    // Target date
                    Label {
                        text: "Дата: " + (modelData.targetDate || "")
                        font.pixelSize: 11; color: goalsList.textMuted
                    }

                    // Progress bar (only if progress field exists)
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 4
                        visible: modelData.progress !== undefined

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: "Прогресс"
                                font.pixelSize: 10; font.weight: Font.Black
                                color: goalsList.textMuted; font.letterSpacing: 0.8
                            }
                            Item { Layout.fillWidth: true }
                            Label {
                                text: Math.round((modelData.progress || 0) * 100) + "%"
                                font.pixelSize: 11; font.weight: Font.Bold
                                color: goalsList.accent
                            }
                        }

                        // Progress bar track
                        Rectangle {
                            Layout.fillWidth: true; height: 6; radius: 3
                            color: goalsList.dark ? "#30363d" : "#e2e8f0"
                            Rectangle {
                                width: Math.min(1.0, modelData.progress || 0) * parent.width
                                height: parent.height; radius: 3
                                color: goalsList.accent
                                Behavior on width { NumberAnimation { duration: 500 } }
                            }
                        }
                    }
                }
            }
        }

        // Empty state
        Rectangle {
            width: goalsCol.width; height: 60
            visible: goalsList.goalsModel.length === 0
            color: "transparent"
            Label {
                anchors.centerIn: parent
                text: "Целей пока нет — нажмите ＋ чтобы добавить"
                font.pixelSize: 12; color: goalsList.textMuted
            }
        }
    }
}
