import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

Item {
    id: routeTab

    // ── Theme ─────────────────────────────────────────────────────────────────
    property color bg:          "#f0f2f5"
    property color surface:     "#ffffff"
    property color surface2:    "#f6f8fa"
    property color borderCol:   "#dde3eb"
    property color textPrimary: "#0d1117"
    property color textMuted:   "#57606a"
    property color accent:      "#6366f1"
    property color runColor:    "#22c55e"
    property color hardColor:   "#ef4444"
    property bool  dark:        false

    // ── Data ─────────────────────────────────────────────────────────────────
    property var    routesModel:  []
    property bool   isBusy:       false
    property bool   hasOpenAiKey: false
    property var    selectedRoute: null

    // ── Signals ───────────────────────────────────────────────────────────────
    signal generateRequested(real lat, real lon, real distKm, string prefs)
    signal deleteRouteRequested(string id)
    signal openAiKeyRequested()

    // ── Generate form state ───────────────────────────────────────────────────
    property real   genLat:  55.7558
    property real   genLon:  37.6173
    property real   genDist: 5.0
    property string genPrefs: ""

    // Parse routeCoords from selected route's GeoJSON
    property var routeCoords: []
    onSelectedRouteChanged: {
        if (!selectedRoute || !selectedRoute.geojson) { routeCoords = []; return }
        try {
            var geo = JSON.parse(selectedRoute.geojson)
            routeCoords = geo.coordinates || []
        } catch(e) { routeCoords = [] }
    }

    // ── Layout ────────────────────────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Left sidebar ──────────────────────────────────────────────────────
        Rectangle {
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            color: surface

            Rectangle {
                anchors { top: parent.top; right: parent.right; bottom: parent.bottom }
                width: 1; color: borderCol
            }

            ColumnLayout {
                anchors { fill: parent; margins: 16 }
                spacing: 12

                Label {
                    text: "Маршруты"
                    font.pixelSize: 17; font.weight: Font.Black
                    color: textPrimary; font.letterSpacing: -0.3
                }

                // ── OpenAI key banner ─────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    visible: !routeTab.hasOpenAiKey
                    height: visible ? nkInner.implicitHeight + 20 : 0
                    radius: 10
                    color: dark ? "#1a1a3a" : "#f5f3ff"
                    border.width: 1; border.color: accent + "40"

                    ColumnLayout {
                        id: nkInner
                        anchors { fill: parent; margins: 12 }
                        spacing: 8

                        Label {
                            text: "Нужен OpenAI API ключ"
                            font.pixelSize: 12; font.weight: Font.DemiBold; color: accent
                        }
                        Label {
                            Layout.fillWidth: true
                            text: "Добавьте ключ чтобы ИИ мог генерировать маршруты. Одна генерация ≈ $0.001."
                            font.pixelSize: 11; color: textMuted; wrapMode: Text.Wrap
                        }
                        Rectangle {
                            width: addKeyLbl.implicitWidth + 18; height: 28; radius: 7; color: accent
                            Label { id: addKeyLbl; anchors.centerIn: parent
                                    text: "Добавить ключ"; font.pixelSize: 11; font.weight: Font.DemiBold; color: "#fff" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: routeTab.openAiKeyRequested() }
                        }
                    }
                }

                // ── Generate form ─────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    visible: routeTab.hasOpenAiKey
                    height: visible ? genInner.implicitHeight + 20 : 0
                    radius: 10; color: surface2
                    border.width: 1; border.color: borderCol

                    ColumnLayout {
                        id: genInner
                        anchors { fill: parent; margins: 12 }
                        spacing: 10

                        Label {
                            text: "Новый маршрут"
                            font.pixelSize: 12; font.weight: Font.DemiBold; color: textPrimary
                        }

                        // Lat / Lon row
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                Label { text: "Широта"; font.pixelSize: 10; color: textMuted }
                                TextField {
                                    Layout.fillWidth: true; implicitHeight: 32; font.pixelSize: 12
                                    text: routeTab.genLat.toFixed(4)
                                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                                    onEditingFinished: { var v = parseFloat(text); if (!isNaN(v)) routeTab.genLat = v }
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                Label { text: "Долгота"; font.pixelSize: 10; color: textMuted }
                                TextField {
                                    Layout.fillWidth: true; implicitHeight: 32; font.pixelSize: 12
                                    text: routeTab.genLon.toFixed(4)
                                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                                    onEditingFinished: { var v = parseFloat(text); if (!isNaN(v)) routeTab.genLon = v }
                                }
                            }
                        }

                        // Distance slider
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "Длина"; font.pixelSize: 10; color: textMuted }
                                Item { Layout.fillWidth: true }
                                Label {
                                    text: routeTab.genDist.toFixed(1) + " км"
                                    font.pixelSize: 12; font.weight: Font.DemiBold; color: accent
                                }
                            }
                            Slider {
                                Layout.fillWidth: true; from: 1; to: 42; stepSize: 0.5
                                value: routeTab.genDist
                                onValueChanged: routeTab.genDist = value
                            }
                        }

                        // Preferences
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2
                            Label { text: "Предпочтения (необязательно)"; font.pixelSize: 10; color: textMuted }
                            TextField {
                                Layout.fillWidth: true; implicitHeight: 32; font.pixelSize: 12
                                placeholderText: "парки, набережная, тихие улицы..."
                                onTextChanged: routeTab.genPrefs = text
                            }
                        }

                        // Generate button
                        Rectangle {
                            Layout.fillWidth: true; height: 36; radius: 8
                            color: routeTab.isBusy ? borderCol : accent
                            opacity: routeTab.isBusy ? 0.7 : 1.0

                            RowLayout {
                                anchors.centerIn: parent; spacing: 6
                                BusyIndicator { width: 18; height: 18; visible: routeTab.isBusy; running: routeTab.isBusy }
                                Label {
                                    text: routeTab.isBusy ? "Генерирую..." : "✨  Сгенерировать маршрут"
                                    font.pixelSize: 12; font.weight: Font.DemiBold; color: "#fff"
                                }
                            }
                            MouseArea {
                                anchors.fill: parent; enabled: !routeTab.isBusy; cursorShape: Qt.PointingHandCursor
                                onClicked: routeTab.generateRequested(routeTab.genLat, routeTab.genLon, routeTab.genDist, routeTab.genPrefs)
                            }
                        }
                    }
                }

                // ── Routes list label ─────────────────────────────────────────
                Label {
                    text: "СОХРАНЁННЫЕ"
                    font.pixelSize: 9; font.weight: Font.Black
                    color: textMuted; font.letterSpacing: 1.2
                }

                // ── Routes list ───────────────────────────────────────────────
                ListView {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    model: routeTab.routesModel; spacing: 6; clip: true

                    delegate: Rectangle {
                        width: ListView.view.width; height: 56; radius: 10
                        color: routeTab.selectedRoute && routeTab.selectedRoute.id === modelData.id
                               ? (dark ? "#1f1a40" : "#f5f3ff") : surface2
                        border.width: routeTab.selectedRoute && routeTab.selectedRoute.id === modelData.id ? 1.5 : 0
                        border.color: accent

                        Rectangle { width: 3; height: parent.height; radius: 3; color: runColor }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                            spacing: 8
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                Label { text: modelData.name || "Маршрут"; font.pixelSize: 12; font.weight: Font.DemiBold; color: textPrimary; elide: Text.ElideRight }
                                Label { text: (modelData.distanceKm || 0).toFixed(1) + " км"; font.pixelSize: 11; color: textMuted }
                            }
                            RoundButton {
                                width: 22; height: 22; radius: 6; flat: true; text: "×"; font.pixelSize: 13
                                onClicked: routeTab.deleteRouteRequested(modelData.id)
                            }
                        }

                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: routeTab.selectedRoute = modelData }
                    }

                    Label {
                        anchors.centerIn: parent
                        visible: routeTab.routesModel.length === 0
                        text: routeTab.hasOpenAiKey ? "Маршрутов пока нет" : "Добавьте ключ чтобы начать"
                        font.pixelSize: 12; color: textMuted
                    }
                }
            }
        }

        // ── Main area: map + info ─────────────────────────────────────────────
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true

            // Empty state
            ColumnLayout {
                anchors.centerIn: parent
                visible: !routeTab.selectedRoute
                spacing: 10
                Label { Layout.alignment: Qt.AlignHCenter; text: "🗺️"; font.pixelSize: 56 }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: routeTab.hasOpenAiKey ? "Выберите маршрут или сгенерируйте новый" : "Добавьте OpenAI ключ в Настройках чтобы начать"
                    font.pixelSize: 14; color: textMuted
                }
            }

            // Map + description when route selected
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 16; spacing: 12
                visible: !!routeTab.selectedRoute

                // Route title row
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Label {
                            text: routeTab.selectedRoute ? (routeTab.selectedRoute.name || "Маршрут") : ""
                            font.pixelSize: 18; font.weight: Font.Black; color: textPrimary; font.letterSpacing: -0.3
                        }
                        Label {
                            text: routeTab.selectedRoute
                                  ? ((routeTab.selectedRoute.distanceKm || 0).toFixed(1) + " км")
                                  : ""
                            font.pixelSize: 12; color: textMuted
                        }
                    }

                    // Open on OSM button
                    Rectangle {
                        height: 32; width: osmLbl.implicitWidth + 16; radius: 8
                        color: surface; border.width: 1; border.color: borderCol
                        Label {
                            id: osmLbl; anchors.centerIn: parent
                            text: "🌍  Открыть на OSM"
                            font.pixelSize: 12; color: accent; font.weight: Font.DemiBold
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (routeTab.selectedRoute) {
                                    var lat = routeTab.selectedRoute.startLat || 55.75
                                    var lon = routeTab.selectedRoute.startLon || 37.62
                                    Qt.openUrlExternally("https://www.openstreetmap.org/?mlat=" + lat + "&mlon=" + lon + "&zoom=14")
                                }
                            }
                        }
                    }
                }

                // ── The real OSM tile map ─────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    radius: 12; clip: true
                    border.width: 1; border.color: borderCol

                    TileMap {
                        id: theMap
                        anchors.fill: parent
                        dark:         routeTab.dark
                        lineColor:    routeTab.accent
                        routeCoords:  routeTab.routeCoords
                        // Default center from generate form
                        centerLat:    routeTab.selectedRoute ? (routeTab.selectedRoute.startLat || routeTab.genLat) : routeTab.genLat
                        centerLon:    routeTab.selectedRoute ? (routeTab.selectedRoute.startLon || routeTab.genLon) : routeTab.genLon
                    }
                }

                // ── Description card ──────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    visible: !!routeTab.selectedRoute && !!(routeTab.selectedRoute.description)
                    height: visible ? descInner.implicitHeight + 20 : 0
                    radius: 10; color: surface
                    border.width: 1; border.color: borderCol

                    ColumnLayout {
                        id: descInner
                        anchors { fill: parent; margins: 14 }
                        spacing: 6
                        Label { text: "ОПИСАНИЕ"; font.pixelSize: 9; font.weight: Font.Black; color: textMuted; font.letterSpacing: 1 }
                        Label {
                            Layout.fillWidth: true
                            text: routeTab.selectedRoute ? (routeTab.selectedRoute.description || "") : ""
                            font.pixelSize: 13; color: textPrimary; wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }
    }
}
