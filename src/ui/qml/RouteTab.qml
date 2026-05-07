import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

// ── Маршруты — ИИ генерация + просмотр ─────────────────────────────────────
Item {
    id: routeTab

    // Theme (pass from root)
    property color bg:          "#f0f2f5"
    property color surface:     "#ffffff"
    property color surface2:    "#f6f8fa"
    property color borderCol:   "#dde3eb"
    property color textPrimary: "#0d1117"
    property color textMuted:   "#57606a"
    property color accent:      "#6366f1"
    property color runColor:    "#22c55e"
    property color hardColor:   "#ef4444"
    property bool  dark: false

    property var   routesModel:  []
    property bool  isBusy:       false
    property bool  hasOpenAiKey: false

    // Currently shown route
    property var   selectedRoute: null

    signal generateRequested(real lat, real lon, real distKm, string prefs)
    signal deleteRouteRequested(string id)
    signal openAiKeyRequested()

    // Generation form state
    property real  genLat:   55.7558   // Moscow default (user can change)
    property real  genLon:   37.6173
    property real  genDist:  5.0
    property string genPrefs: ""

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Left panel: form + list ──────────────────────────────────────────
        Rectangle {
            Layout.preferredWidth: 320; Layout.fillHeight: true
            color: surface

            Rectangle {
                anchors { top: parent.top; right: parent.right; bottom: parent.bottom }
                width: 1; color: borderCol
            }

            ColumnLayout {
                anchors { fill: parent; margins: 16 }
                spacing: 12

                // Header
                Label {
                    text: "🗺️  Маршруты"
                    font.pixelSize: 18; font.weight: Font.Black
                    color: textPrimary; font.letterSpacing: -0.3
                }

                // OpenAI key banner (shown when key not set)
                Rectangle {
                    Layout.fillWidth: true
                    visible: !routeTab.hasOpenAiKey
                    height: visible ? keyBannerCol.implicitHeight + 20 : 0
                    radius: 10
                    color: dark ? "#1a1a3a" : "#eef2ff"
                    border.width: 1; border.color: accent + "44"

                    ColumnLayout {
                        id: keyBannerCol
                        anchors { fill: parent; margins: 12 }
                        spacing: 8

                        Label {
                            text: "Требуется OpenAI API ключ"
                            font.pixelSize: 13; font.weight: Font.DemiBold
                            color: accent
                        }
                        Label {
                            Layout.fillWidth: true
                            text: "Для генерации маршрутов введите ваш OpenAI API ключ."
                            font.pixelSize: 11; color: textMuted; wrapMode: Text.Wrap
                        }
                        Rectangle {
                            width: keyBtnLbl.implicitWidth + 20; height: 30; radius: 8
                            color: accent
                            Label {
                                id: keyBtnLbl; anchors.centerIn: parent
                                text: "Добавить ключ"
                                font.pixelSize: 12; font.weight: Font.DemiBold; color: "#fff"
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: routeTab.openAiKeyRequested()
                            }
                        }
                    }
                }

                // Generate form (shown when key set)
                Rectangle {
                    Layout.fillWidth: true
                    visible: routeTab.hasOpenAiKey
                    height: visible ? genFormCol.implicitHeight + 20 : 0
                    radius: 10; color: surface2
                    border.width: 1; border.color: borderCol

                    ColumnLayout {
                        id: genFormCol
                        anchors { fill: parent; margins: 12 }
                        spacing: 8

                        Label {
                            text: "Новый маршрут"
                            font.pixelSize: 13; font.weight: Font.DemiBold; color: textPrimary
                        }

                        GridLayout {
                            columns: 2; columnSpacing: 8; rowSpacing: 6
                            Layout.fillWidth: true

                            Label { text: "Широта"; font.pixelSize: 11; color: textMuted }
                            Label { text: "Долгота"; font.pixelSize: 11; color: textMuted }

                            TextField {
                                id: latField
                                Layout.fillWidth: true; implicitHeight: 32
                                text: routeTab.genLat.toFixed(4)
                                inputMethodHints: Qt.ImhFormattedNumbersOnly
                                font.pixelSize: 12
                                onTextChanged: { var v = parseFloat(text); if (!isNaN(v)) routeTab.genLat = v }
                            }
                            TextField {
                                id: lonField
                                Layout.fillWidth: true; implicitHeight: 32
                                text: routeTab.genLon.toFixed(4)
                                inputMethodHints: Qt.ImhFormattedNumbersOnly
                                font.pixelSize: 12
                                onTextChanged: { var v = parseFloat(text); if (!isNaN(v)) routeTab.genLon = v }
                            }
                        }

                        Label { text: "Длина (км)"; font.pixelSize: 11; color: textMuted }
                        Slider {
                            id: distSlider
                            Layout.fillWidth: true
                            from: 1; to: 42; stepSize: 0.5
                            value: routeTab.genDist
                            onValueChanged: routeTab.genDist = value
                        }
                        Label {
                            text: routeTab.genDist.toFixed(1) + " км"
                            font.pixelSize: 13; font.weight: Font.DemiBold; color: accent
                        }

                        Label { text: "Предпочтения"; font.pixelSize: 11; color: textMuted }
                        TextField {
                            Layout.fillWidth: true; implicitHeight: 32
                            placeholderText: "парки, тихие улицы, набережная..."
                            font.pixelSize: 12
                            onTextChanged: routeTab.genPrefs = text
                        }

                        RowLayout {
                            Layout.fillWidth: true; spacing: 8

                            Rectangle {
                                Layout.fillWidth: true; height: 34; radius: 8
                                color: routeTab.isBusy ? borderCol : accent
                                opacity: routeTab.isBusy ? 0.7 : 1.0

                                RowLayout {
                                    anchors.centerIn: parent; spacing: 6
                                    BusyIndicator {
                                        width: 18; height: 18
                                        visible: routeTab.isBusy
                                        running: routeTab.isBusy
                                    }
                                    Label {
                                        text: routeTab.isBusy ? "Генерирую..." : "✨ Сгенерировать"
                                        font.pixelSize: 12; font.weight: Font.DemiBold; color: "#fff"
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: !routeTab.isBusy
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: routeTab.generateRequested(
                                        routeTab.genLat, routeTab.genLon,
                                        routeTab.genDist, routeTab.genPrefs)
                                }
                            }

                            Rectangle {
                                width: 34; height: 34; radius: 8
                                color: surface; border.width: 1; border.color: borderCol
                                Label { anchors.centerIn: parent; text: "🔑"; font.pixelSize: 16 }
                                ToolTip.text: "Изменить OpenAI ключ"
                                ToolTip.visible: keyHov.containsMouse; ToolTip.delay: 300
                                MouseArea {
                                    id: keyHov; anchors.fill: parent
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: routeTab.openAiKeyRequested()
                                }
                            }
                        }
                    }
                }

                // Routes list
                Label {
                    text: "СОХРАНЁННЫЕ МАРШРУТЫ"
                    font.pixelSize: 9; font.weight: Font.Black
                    color: textMuted; font.letterSpacing: 1
                }

                ListView {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    model: routeTab.routesModel
                    spacing: 6; clip: true

                    delegate: Rectangle {
                        width: ListView.view.width; height: routeItemCol.implicitHeight + 16
                        radius: 10
                        color: routeTab.selectedRoute && routeTab.selectedRoute.id === modelData.id
                               ? (dark ? "#1f1a40" : "#ede9fe") : surface2
                        border.width: routeTab.selectedRoute && routeTab.selectedRoute.id === modelData.id ? 1.5 : 0
                        border.color: accent

                        // Left color bar
                        Rectangle {
                            width: 4; height: parent.height; radius: 3
                            color: runColor
                        }

                        ColumnLayout {
                            id: routeItemCol
                            anchors { fill: parent; leftMargin: 14; rightMargin: 10; top: parent.top; topMargin: 8 }
                            spacing: 3

                            RowLayout {
                                Layout.fillWidth: true
                                Label {
                                    text: modelData.name || "Маршрут"
                                    font.pixelSize: 12; font.weight: Font.DemiBold
                                    color: textPrimary; Layout.fillWidth: true; elide: Text.ElideRight
                                }
                                RoundButton {
                                    width: 20; height: 20; radius: 5; flat: true
                                    text: "×"; font.pixelSize: 12
                                    onClicked: routeTab.deleteRouteRequested(modelData.id)
                                }
                            }
                            Label {
                                text: (modelData.distanceKm || 0).toFixed(1) + " км"
                                font.pixelSize: 11; color: textMuted
                            }
                        }

                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: routeTab.selectedRoute = modelData
                        }
                    }

                    Label {
                        anchors.centerIn: parent
                        visible: routeTab.routesModel.length === 0
                        text: "Маршрутов пока нет"
                        font.pixelSize: 12; color: textMuted
                    }
                }
            }
        }

        // ── Right panel: map + description ───────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true
            color: bg

            // Empty state
            ColumnLayout {
                anchors.centerIn: parent
                visible: !routeTab.selectedRoute
                spacing: 12

                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: "🗺️"; font.pixelSize: 64
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: routeTab.hasOpenAiKey
                          ? "Сгенерируйте маршрут или выберите из списка"
                          : "Добавьте OpenAI API ключ чтобы начать"
                    font.pixelSize: 14; color: textMuted
                }
            }

            // Route detail (when selected)
            ColumnLayout {
                anchors { fill: parent; margins: 20 }
                spacing: 14
                visible: !!routeTab.selectedRoute

                // Route header
                RowLayout {
                    Layout.fillWidth: true; spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 4
                        Label {
                            text: routeTab.selectedRoute ? (routeTab.selectedRoute.name || "Маршрут") : ""
                            font.pixelSize: 20; font.weight: Font.Black; color: textPrimary; font.letterSpacing: -0.3
                        }
                        Label {
                            text: routeTab.selectedRoute
                                  ? ((routeTab.selectedRoute.distanceKm || 0).toFixed(1) + " км")
                                  : ""
                            font.pixelSize: 13; color: textMuted
                        }
                    }

                    // Open on OSM button
                    Rectangle {
                        height: 34; width: osmBtnLbl.implicitWidth + 20; radius: 8
                        color: surface; border.width: 1; border.color: borderCol
                        Label {
                            id: osmBtnLbl; anchors.centerIn: parent
                            text: "🌍 Открыть на карте"
                            font.pixelSize: 12; color: accent; font.weight: Font.DemiBold
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (routeTab.selectedRoute) {
                                    var lat = routeTab.selectedRoute.startLat || 0
                                    var lon = routeTab.selectedRoute.startLon || 0
                                    Qt.openUrlExternally(
                                        "https://www.openstreetmap.org/?mlat=" + lat
                                        + "&mlon=" + lon + "&zoom=14"
                                    )
                                }
                            }
                        }
                    }
                }

                // Canvas map (draws route polyline from GeoJSON)
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    radius: 12; color: dark ? "#1a2030" : "#e8f0e8"
                    border.width: 1; border.color: borderCol
                    clip: true

                    Canvas {
                        id: routeCanvas
                        anchors.fill: parent

                        property var coords: []

                        // Parse GeoJSON and build coords array when route changes
                        function loadRoute(route) {
                            if (!route || !route.geojson) { coords = []; requestPaint(); return }
                            try {
                                var geo = JSON.parse(route.geojson)
                                coords = geo.coordinates || []
                            } catch(e) {
                                coords = []
                            }
                            requestPaint()
                        }

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)

                            if (!coords || coords.length < 2) {
                                ctx.fillStyle = textMuted
                                ctx.font = "14px sans-serif"
                                ctx.textAlign = "center"
                                ctx.fillText("Нет данных маршрута", width / 2, height / 2)
                                return
                            }

                            // Project lon/lat → canvas coordinates
                            var minLon = coords[0][0], maxLon = coords[0][0]
                            var minLat = coords[0][1], maxLat = coords[0][1]
                            for (var i = 1; i < coords.length; i++) {
                                if (coords[i][0] < minLon) minLon = coords[i][0]
                                if (coords[i][0] > maxLon) maxLon = coords[i][0]
                                if (coords[i][1] < minLat) minLat = coords[i][1]
                                if (coords[i][1] > maxLat) maxLat = coords[i][1]
                            }

                            var pad = 40
                            var rangeX = maxLon - minLon || 0.001
                            var rangeY = maxLat - minLat || 0.001
                            var scaleX = (width  - pad * 2) / rangeX
                            var scaleY = (height - pad * 2) / rangeY
                            var scale  = Math.min(scaleX, scaleY)
                            var offX   = pad + (width  - pad * 2 - rangeX * scale) / 2
                            var offY   = pad + (height - pad * 2 - rangeY * scale) / 2

                            function toX(lon) { return offX + (lon - minLon) * scale }
                            function toY(lat) { return height - (offY + (lat - minLat) * scale) }

                            // Draw subtle grid (background OSM-style)
                            ctx.strokeStyle = dark ? "#ffffff18" : "#00000012"
                            ctx.lineWidth = 1
                            for (var gx = 0; gx < width; gx += 40) {
                                ctx.beginPath(); ctx.moveTo(gx, 0); ctx.lineTo(gx, height); ctx.stroke()
                            }
                            for (var gy = 0; gy < height; gy += 40) {
                                ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(width, gy); ctx.stroke()
                            }

                            // Draw route line with glow effect
                            ctx.shadowBlur = 8
                            ctx.shadowColor = "#6366f1"
                            ctx.strokeStyle = "#6366f1"
                            ctx.lineWidth = 4
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"
                            ctx.beginPath()
                            ctx.moveTo(toX(coords[0][0]), toY(coords[0][1]))
                            for (var p = 1; p < coords.length; p++) {
                                ctx.lineTo(toX(coords[p][0]), toY(coords[p][1]))
                            }
                            ctx.stroke()
                            ctx.shadowBlur = 0

                            // Start/end markers
                            var sx = toX(coords[0][0]), sy = toY(coords[0][1])
                            var ex = toX(coords[coords.length-1][0]), ey = toY(coords[coords.length-1][1])

                            // Start — green circle
                            ctx.fillStyle = "#22c55e"
                            ctx.beginPath(); ctx.arc(sx, sy, 8, 0, Math.PI * 2); ctx.fill()
                            ctx.fillStyle = "#fff"
                            ctx.beginPath(); ctx.arc(sx, sy, 4, 0, Math.PI * 2); ctx.fill()

                            // End — same as start (circular route)
                            ctx.fillStyle = "#6366f1"
                            ctx.beginPath(); ctx.arc(ex, ey, 6, 0, Math.PI * 2); ctx.fill()
                        }

                        Connections {
                            target: routeTab
                            function onSelectedRouteChanged() {
                                routeCanvas.loadRoute(routeTab.selectedRoute)
                            }
                        }
                    }

                    // Label overlay
                    Label {
                        anchors { top: parent.top; left: parent.left; margins: 12 }
                        text: "🟢 Старт   🔵 Финиш"
                        font.pixelSize: 10; color: textMuted
                        background: Rectangle {
                            color: surface; radius: 6; opacity: 0.85
                            anchors { fill: parent; margins: -4 }
                        }
                    }
                }

                // Description text
                Rectangle {
                    Layout.fillWidth: true
                    visible: !!routeTab.selectedRoute && !!(routeTab.selectedRoute.description)
                    height: visible ? descCol.implicitHeight + 20 : 0
                    radius: 10; color: surface
                    border.width: 1; border.color: borderCol

                    ColumnLayout {
                        id: descCol
                        anchors { fill: parent; margins: 14 }
                        spacing: 6
                        Label {
                            text: "ОПИСАНИЕ МАРШРУТА"
                            font.pixelSize: 9; font.weight: Font.Black
                            color: textMuted; font.letterSpacing: 1
                        }
                        Label {
                            Layout.fillWidth: true
                            text: routeTab.selectedRoute ? (routeTab.selectedRoute.description || "") : ""
                            font.pixelSize: 13; color: textPrimary
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }
    }
}
