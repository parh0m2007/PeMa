import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: goalDialog
    title: "Новая цель"
    modal: true
    anchors.centerIn: Overlay.overlay
    width: 360
    standardButtons: Dialog.Ok | Dialog.Cancel

    // Theme properties (injected from root)
    property color surface:     "#ffffff"
    property color surface2:    "#f6f8fa"
    property color borderCol:   "#dde3eb"
    property color textPrimary: "#0d1117"
    property color textMuted:   "#57606a"
    property color accent:      "#6366f1"

    signal goalCreated(string title, string targetDate, string type,
                       real targetValue, string targetUnit)

    onOpened: {
        goalTitleField.text    = ""
        goalDateField.text     = Qt.formatDate(new Date(), "yyyy-MM-dd")
        goalTypeCombo.currentIndex = 0
        goalValueSpin.value    = 42
        goalUnitCombo.currentIndex = 0
    }

    onAccepted: {
        var title = goalTitleField.text.trim()
        if (!title) return
        var unit = goalUnitCombo.currentIndex === 0 ? "km" : "runs"
        goalCreated(title, goalDateField.text, "volume",
                    goalValueSpin.value, unit)
    }

    ColumnLayout {
        spacing: 12
        width: parent.width

        Label {
            text: "Название"
            font.pixelSize: 12; color: goalDialog.textMuted
        }
        TextField {
            id: goalTitleField
            Layout.fillWidth: true; implicitHeight: 36
            placeholderText: "Например: Марафон Москва"
        }

        Label {
            text: "Дата цели (YYYY-MM-DD)"
            font.pixelSize: 12; color: goalDialog.textMuted
        }
        TextField {
            id: goalDateField
            Layout.fillWidth: true; implicitHeight: 36
            placeholderText: "2026-09-15"
        }

        Label {
            text: "Объём до цели"
            font.pixelSize: 12; color: goalDialog.textMuted
        }
        RowLayout {
            spacing: 8
            SpinBox {
                id: goalValueSpin
                from: 1; to: 10000; value: 42
                implicitHeight: 36; implicitWidth: 120
            }
            ComboBox {
                id: goalUnitCombo
                implicitHeight: 36
                model: ["км", "пробежек"]
            }
        }
    }
}
