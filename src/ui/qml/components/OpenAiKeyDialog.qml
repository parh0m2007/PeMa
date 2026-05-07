import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: dialog
    title: "OpenAI API ключ"
    modal: true
    anchors.centerIn: Overlay.overlay
    width: 400
    standardButtons: Dialog.Ok | Dialog.Cancel

    property color textMuted:   "#57606a"
    property color accent:      "#6366f1"
    property color surface2:    "#f6f8fa"
    property color borderCol:   "#dde3eb"
    property bool  hasKey: false

    signal keySet(string key)
    signal keyCleared()

    onOpened: {
        keyField.text = ""
        keyField.echoMode = TextInput.Password
        showKeyCheck.checked = false
    }
    onAccepted: {
        var k = keyField.text.trim()
        if (k.length > 0) {
            keySet(k)
        }
    }

    ColumnLayout {
        spacing: 12
        width: parent.width

        Label {
            Layout.fillWidth: true
            text: "Введите ваш OpenAI API ключ (sk-...). "
                + "Ключ хранится только на сервере и используется для генерации маршрутов."
            font.pixelSize: 12; color: dialog.textMuted
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 8
            TextField {
                id: keyField
                Layout.fillWidth: true; implicitHeight: 36
                placeholderText: "sk-..."
                echoMode: showKeyCheck.checked ? TextInput.Normal : TextInput.Password
            }
            CheckBox {
                id: showKeyCheck
                text: "Показать"
                font.pixelSize: 11
            }
        }

        Label {
            text: dialog.hasKey
                  ? "✓ Ключ уже задан — введите новый чтобы заменить"
                  : "Ключ ещё не задан"
            font.pixelSize: 11
            color: dialog.hasKey ? "#22c55e" : dialog.textMuted
        }

        Label {
            Layout.fillWidth: true
            text: "Цена: ~$0.001 за маршрут (gpt-4o-mini). Это ваш ключ — затраты идут на ваш аккаунт."
            font.pixelSize: 10; color: dialog.textMuted; wrapMode: Text.Wrap
        }
    }
}
