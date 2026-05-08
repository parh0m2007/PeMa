import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: root
    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    width: 480
    padding: 0
    closePolicy: Popup.NoAutoClose

    property string dialogTitle:     "Новая тренировка"
    property string draftDateIso:    ""
    property string workoutTitle:    ""
    property string workoutCategory: "run"
    property real   workoutDistance: 5
    property int    workoutDuration: 45
    property string workoutIntensity:"moderate"
    property string workoutNotes:    ""
    property bool   workoutHidden:   false
    property bool   hasDistance:     true
    property bool   hasDuration:     true
    property string errorText:       ""
    property bool   saveEnabled:     true
    property string saveDisabledHint:""
    property bool   busy:            false
    property var    categories:      []
    property var    intensities:     []

    signal cancelRequested()
    signal saveRequested(
        string title, string category, real distanceKm, int durationMin,
        string intensity, string notes, bool hiddenFromAthlete
    )

    onClosed: cancelRequested()

    // ── Window chrome ──────────────────────────────────────────────────────
    background: Rectangle {
        radius: 14
        color: "#ffffff"
        layer.enabled: true
        layer.effect: null
        border.width: 1
        border.color: "#e2e8f0"

        // Shadow simulation via outer rect
        Rectangle {
            anchors { fill: parent; margins: -1 }
            radius: parent.radius + 1
            color: "transparent"
            border.width: 1
            border.color: "#00000018"
            z: -1
        }
    }

    ColumnLayout {
        width: root.width
        spacing: 0

        // ── Header ─────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 56
            radius: 14
            // flat bottom corners
            Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 14; color: parent.color }
            color: "#f8fafc"

            RowLayout {
                anchors { fill: parent; leftMargin: 20; rightMargin: 12 }
                Column {
                    spacing: 2
                    Label {
                        text: root.dialogTitle
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        color: "#0f172a"
                    }
                    Label {
                        text: root.draftDateIso
                        font.pixelSize: 12
                        color: "#6366f1"
                    }
                }
                Item { Layout.fillWidth: true }
                RoundButton {
                    width: 30; height: 30; radius: 8
                    flat: true
                    text: "✕"
                    font.pixelSize: 14
                    onClicked: root.cancelRequested()
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#e2e8f0" }

        // ── Form body ──────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: 20
            spacing: 14

            // Category
            ColumnLayout { spacing: 4; Layout.fillWidth: true
                Label { text: "Категория"; font.pixelSize: 12; font.weight: Font.DemiBold; color: "#374151" }
                ComboBox {
                    Layout.fillWidth: true; implicitHeight: 38
                    model: root.categories
                    currentIndex: Math.max(0, model.indexOf(root.workoutCategory))
                    enabled: !root.busy
                    onActivated: root.workoutCategory = currentText
                }
            }

            // Title
            ColumnLayout { spacing: 4; Layout.fillWidth: true
                Label { text: "Название"; font.pixelSize: 12; font.weight: Font.DemiBold; color: "#374151" }
                TextField {
                    Layout.fillWidth: true; implicitHeight: 38
                    text: root.workoutTitle
                    placeholderText: "Например: Бег — интервалы"
                    enabled: !root.busy
                    onTextChanged: root.workoutTitle = text
                }
            }

            // Distance
            ColumnLayout { spacing: 4; Layout.fillWidth: true
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "Дистанция (км)"; font.pixelSize: 12; font.weight: Font.DemiBold; color: "#374151"; Layout.fillWidth: true }
                    CheckBox {
                        text: "Указать"
                        checked: root.hasDistance
                        onToggled: root.hasDistance = checked
                        font.pixelSize: 11
                    }
                }
                SpinBox {
                    Layout.fillWidth: true; implicitHeight: 38
                    from: 0; to: 500
                    value: Math.round(root.workoutDistance)
                    enabled: !root.busy && root.hasDistance
                    opacity: root.hasDistance ? 1 : 0.35
                    onValueModified: root.workoutDistance = value
                }
            }

            // Duration
            ColumnLayout { spacing: 4; Layout.fillWidth: true
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "Длительность (мин)"; font.pixelSize: 12; font.weight: Font.DemiBold; color: "#374151"; Layout.fillWidth: true }
                    CheckBox {
                        text: "Указать"
                        checked: root.hasDuration
                        onToggled: root.hasDuration = checked
                        font.pixelSize: 11
                    }
                }
                SpinBox {
                    Layout.fillWidth: true; implicitHeight: 38
                    from: 0; to: 600
                    value: root.workoutDuration
                    enabled: !root.busy && root.hasDuration
                    opacity: root.hasDuration ? 1 : 0.35
                    onValueModified: root.workoutDuration = value
                }
            }

            // Intensity
            ColumnLayout { spacing: 4; Layout.fillWidth: true
                Label { text: "Интенсивность"; font.pixelSize: 12; font.weight: Font.DemiBold; color: "#374151" }
                ComboBox {
                    Layout.fillWidth: true; implicitHeight: 38
                    model: root.intensities
                    currentIndex: Math.max(0, model.indexOf(root.workoutIntensity))
                    enabled: !root.busy
                    onActivated: root.workoutIntensity = currentText
                }
            }

            // Notes
            ColumnLayout { spacing: 4; Layout.fillWidth: true
                Label { text: "Заметки"; font.pixelSize: 12; font.weight: Font.DemiBold; color: "#374151" }
                TextArea {
                    Layout.fillWidth: true; implicitHeight: 70
                    text: root.workoutNotes
                    placeholderText: "Темп, пульс, ощущения..."
                    enabled: !root.busy
                    onTextChanged: root.workoutNotes = text
                    background: Rectangle {
                        radius: 6
                        color: "#f8fafc"
                        border.width: 1; border.color: "#e2e8f0"
                    }
                }
            }

            // Hidden checkbox
            CheckBox {
                text: "Скрыть от атлета"
                checked: root.workoutHidden
                enabled: !root.busy
                onToggled: root.workoutHidden = checked
            }

            // Error
            Label {
                Layout.fillWidth: true
                visible: root.errorText.length > 0
                text: "⚠ " + root.errorText
                color: "#ef4444"
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#e2e8f0" }

        // ── Footer ─────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 56
            radius: 14
            // flat top corners
            Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 14; color: parent.color }
            color: "#f8fafc"

            RowLayout {
                anchors { fill: parent; leftMargin: 20; rightMargin: 20 }
                spacing: 10

                Label {
                    visible: !root.saveEnabled && root.saveDisabledHint.length > 0
                    text: root.saveDisabledHint
                    font.pixelSize: 11
                    color: "#94a3b8"
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
                Item { Layout.fillWidth: true }

                Button {
                    text: "Отмена"
                    implicitHeight: 36; implicitWidth: 90
                    flat: true
                    enabled: !root.busy
                    onClicked: root.cancelRequested()
                }
                Button {
                    text: root.busy ? "Сохранение..." : "Сохранить"
                    implicitHeight: 36; implicitWidth: 110
                    highlighted: true
                    enabled: root.saveEnabled && !root.busy
                    onClicked: root.saveRequested(
                        root.workoutTitle, root.workoutCategory,
                        root.hasDistance  ? root.workoutDistance : 0,
                        root.hasDuration  ? root.workoutDuration : 0,
                        root.workoutIntensity, root.workoutNotes,
                        root.workoutHidden
                    )
                }
            }
        }
    }
}
