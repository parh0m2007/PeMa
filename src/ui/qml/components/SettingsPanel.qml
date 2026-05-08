import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * Slide-in settings panel from the right edge of the window.
 * Call open() / close() to show/hide.
 */
Item {
    id: panel
    visible: _open || drawerAnim.running || overlayAnim.running

    property bool _open: false

    // ── Theme ─────────────────────────────────────────────────────────────────
    property color bg:          "#f0f2f5"
    property color surface:     "#ffffff"
    property color surface2:    "#f6f8fa"
    property color borderCol:   "#dde3eb"
    property color textPrimary: "#0d1117"
    property color textMuted:   "#57606a"
    property color accent:      "#6366f1"
    property bool  dark:        false

    // ── Bindings ──────────────────────────────────────────────────────────────
    property string themeMode:    "light"
    property string serverUrl:    "http://localhost:8000"
    property bool   hasOpenAiKey: false

    signal themeModeChangeRequested(string mode)
    signal serverUrlChangeRequested(string url)
    signal openAiKeyRequested()

    function open()  { _open = true }
    function close() { _open = false }
    function toggle(){ _open = !_open }

    // ── Dim overlay ───────────────────────────────────────────────────────────
    Rectangle {
        id: overlay
        anchors.fill: parent
        color: "#000000"
        opacity: panel._open ? 0.32 : 0.0
        Behavior on opacity { NumberAnimation { id: overlayAnim; duration: 220 } }
        MouseArea { anchors.fill: parent; onClicked: panel.close() }
    }

    // ── Drawer ────────────────────────────────────────────────────────────────
    Rectangle {
        id: drawer
        width: 340
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        x: panel._open ? parent.width - width : parent.width
        Behavior on x { NumberAnimation { id: drawerAnim; duration: 240; easing.type: Easing.OutCubic } }

        color: panel.surface
        // Left shadow line
        Rectangle {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: 1; color: panel.borderCol
        }

        ScrollView {
            anchors.fill: parent
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: parent.width
                anchors { leftMargin: 24; rightMargin: 24; topMargin: 28; bottomMargin: 24 }
                spacing: 24

                // Header
                RowLayout {
                    Layout.fillWidth: true; Layout.leftMargin: 24; Layout.rightMargin: 24
                    Label { text: "Настройки"; font.pixelSize: 18; font.weight: Font.Black; color: panel.textPrimary }
                    Item { Layout.fillWidth: true }
                    RoundButton {
                        width: 28; height: 28; radius: 8; flat: true
                        text: "✕"; font.pixelSize: 14
                        onClicked: panel.close()
                    }
                }

                // ── Внешний вид ──────────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true; Layout.leftMargin: 24; Layout.rightMargin: 24
                    spacing: 8
                    Label { text: "ВНЕШНИЙ ВИД"; font.pixelSize: 9; font.weight: Font.Black; color: panel.textMuted; font.letterSpacing: 1.2 }
                    Rectangle {
                        Layout.fillWidth: true; height: 46; radius: 10
                        color: panel.surface2; border.width: 1; border.color: panel.borderCol
                        RowLayout {
                            anchors { fill: parent; leftMargin: 14; rightMargin: 12 }
                            Label { text: "Тема"; font.pixelSize: 13; color: panel.textPrimary; Layout.fillWidth: true }
                            Row {
                                spacing: 4
                                Repeater {
                                    model: [{ icon:"☀", v:"light" },{ icon:"☾", v:"dark" },{ icon:"⊙", v:"system" }]
                                    Rectangle {
                                        width: 34; height: 28; radius: 7
                                        color: panel.themeMode === modelData.v ? panel.accent : "transparent"
                                        border.width: 1
                                        border.color: panel.themeMode === modelData.v ? panel.accent : panel.borderCol
                                        Label { anchors.centerIn: parent; text: modelData.icon; font.pixelSize: 14;
                                                color: panel.themeMode === modelData.v ? "#fff" : panel.textMuted }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                    onClicked: panel.themeModeChangeRequested(modelData.v) }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Сервер ───────────────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true; Layout.leftMargin: 24; Layout.rightMargin: 24
                    spacing: 8
                    Label { text: "СЕРВЕР"; font.pixelSize: 9; font.weight: Font.Black; color: panel.textMuted; font.letterSpacing: 1.2 }
                    Rectangle {
                        Layout.fillWidth: true; height: 60; radius: 10
                        color: panel.surface2; border.width: 1; border.color: panel.borderCol
                        ColumnLayout {
                            anchors { fill: parent; margins: 12 }
                            spacing: 2
                            Label { text: "URL бэкенда"; font.pixelSize: 10; color: panel.textMuted }
                            TextField {
                                Layout.fillWidth: true; implicitHeight: 30
                                text: panel.serverUrl; font.pixelSize: 12
                                background: Rectangle { color: "transparent" }
                                onEditingFinished: panel.serverUrlChangeRequested(text.trim())
                            }
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        text: "По умолчанию http://localhost:8000 — изменяйте только если запускаете сервер на другом хосте"
                        font.pixelSize: 10; color: panel.textMuted; wrapMode: Text.Wrap
                    }
                }

                // ── ИИ маршруты ──────────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true; Layout.leftMargin: 24; Layout.rightMargin: 24
                    spacing: 8
                    Label { text: "ИИ · МАРШРУТЫ"; font.pixelSize: 9; font.weight: Font.Black; color: panel.textMuted; font.letterSpacing: 1.2 }
                    Rectangle {
                        Layout.fillWidth: true; height: 46; radius: 10
                        color: panel.surface2; border.width: 1; border.color: panel.borderCol
                        RowLayout {
                            anchors { fill: parent; leftMargin: 14; rightMargin: 12 }
                            Column {
                                spacing: 1
                                Label { text: "OpenAI API ключ"; font.pixelSize: 13; color: panel.textPrimary }
                                Label {
                                    text: panel.hasOpenAiKey ? "✓ Задан" : "Не задан"
                                    font.pixelSize: 10
                                    color: panel.hasOpenAiKey ? "#22c55e" : panel.textMuted
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                width: aiLbl.implicitWidth + 16; height: 28; radius: 7; color: panel.accent
                                Label { id: aiLbl; anchors.centerIn: parent
                                        text: panel.hasOpenAiKey ? "Изменить" : "Добавить"
                                        font.pixelSize: 11; font.weight: Font.DemiBold; color: "#fff" }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: panel.openAiKeyRequested() }
                            }
                        }
                    }
                }

                // ── Синхронизация ─────────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true; Layout.leftMargin: 24; Layout.rightMargin: 24
                    spacing: 8
                    Label { text: "СИНХРОНИЗАЦИЯ С ЧАСАМИ"; font.pixelSize: 9; font.weight: Font.Black; color: panel.textMuted; font.letterSpacing: 1.2 }
                    Rectangle {
                        Layout.fillWidth: true; height: syncInner.implicitHeight + 24; radius: 10
                        color: panel.surface2; border.width: 1; border.color: panel.borderCol
                        ColumnLayout {
                            id: syncInner
                            anchors { fill: parent; margins: 14 }
                            spacing: 10

                            Label {
                                Layout.fillWidth: true
                                text: "PeMa принимает файлы .gpx и .fit. Экспортируй активность из приложения своего устройства."
                                font.pixelSize: 12; color: panel.textPrimary; wrapMode: Text.Wrap
                            }

                            // Device list with export instructions
                            Repeater {
                                model: [
                                    { name: "Garmin Connect",  icon: "⌚", color: "#00AAFF", hint: "Activities → выбери тренировку → … → Export Original" },
                                    { name: "Apple Watch",     icon: "🍎", color: "#555",    hint: "Здоровье → Поделиться → Экспортировать данные (.zip с .gpx внутри)" },
                                    { name: "Strava",          icon: "🏅", color: "#FC4C02", hint: "Активность → ⋯ → Экспорт GPX" },
                                    { name: "Polar Flow",      icon: "🔵", color: "#006EFF", hint: "Тренировка → Экспорт → GPX" },
                                    { name: "Suunto App",      icon: "🔴", color: "#C00",    hint: "Упражнение → ⋯ → Экспорт → FIT/GPX" },
                                ]
                                delegate: RowLayout {
                                    Layout.fillWidth: true; spacing: 10
                                    Rectangle {
                                        width: 32; height: 32; radius: 8
                                        color: modelData.color + "20"
                                        border.width: 1; border.color: modelData.color + "44"
                                        Label { anchors.centerIn: parent; text: modelData.icon; font.pixelSize: 16 }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 1
                                        Label { text: modelData.name; font.pixelSize: 12; font.weight: Font.DemiBold; color: panel.textPrimary }
                                        Label { Layout.fillWidth: true; text: modelData.hint; font.pixelSize: 10; color: panel.textMuted; wrapMode: Text.Wrap }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── О приложении ─────────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true; Layout.leftMargin: 24; Layout.rightMargin: 24
                    spacing: 4
                    Label { text: "О ПРИЛОЖЕНИИ"; font.pixelSize: 9; font.weight: Font.Black; color: panel.textMuted; font.letterSpacing: 1.2 }
                    Label { text: "PeMa v2.0"; font.pixelSize: 13; font.weight: Font.DemiBold; color: panel.textPrimary }
                    Label { text: "Qt 6 · FastAPI · SQLite · OpenStreetMap tiles"; font.pixelSize: 11; color: panel.textMuted }
                }

                Item { height: 8 }
            }
        }
    }
}
