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
    property bool  dark:        false

    // ── Data ─────────────────────────────────────────────────────────────────
    property var    routesModel:    []
    property bool   isBusy:         false
    property bool   stravaConnected: false
    property bool   stravaHasClientId: false
    property var    selectedRoute:  null

    // ── Signals ───────────────────────────────────────────────────────────────
    signal generateRequested(real lat, real lon, real distKm, string prefs)
    signal deleteRouteRequested(string id)
    signal buildFromWaypointsRequested(var waypoints, string name)
    signal connectStravaRequested()
    signal disconnectStravaRequested()
    signal syncStravaRequested()
    signal openStravaSettingsRequested()

    // ── Location (set via IP geolocation on load) ─────────────────────────────
    property real defaultLat: 55.7558
    property real defaultLon: 37.6173

    Component.onCompleted: {
        // Fetch approximate location from IP
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "https://ipapi.co/json/")
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4 && xhr.status === 200) {
                try {
                    var d = JSON.parse(xhr.responseText)
                    if (d.latitude && d.longitude) {
                        routeTab.defaultLat = d.latitude
                        routeTab.defaultLon = d.longitude
                    }
                } catch(e) {}
            }
        }
        xhr.send()
    }

    // ── Generate form state ───────────────────────────────────────────────────
    property real   genLat:   defaultLat
    property real   genLon:   defaultLon
    property real   genDist:  5.0
    property string genPrefs: ""

    onDefaultLatChanged: if (genLat === 55.7558) genLat = defaultLat
    onDefaultLonChanged: if (genLon === 37.6173) genLon = defaultLon

    // ── Route coords from selected route GeoJSON ──────────────────────────────
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

            ScrollView {
                anchors.fill: parent
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ColumnLayout {
                    width: parent.width; spacing: 0

                    // Header
                    Rectangle {
                        Layout.fillWidth: true; height: 56; color: "transparent"
                        RowLayout {
                            anchors { fill: parent; leftMargin: 20; rightMargin: 16 }
                            Label {
                                text: "Маршруты"
                                font.pixelSize: 17; font.weight: Font.Black
                                color: textPrimary; font.letterSpacing: -0.3
                                Layout.fillWidth: true
                            }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: borderCol }

                    // ── Strava section ─────────────────────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.leftMargin: 20; Layout.rightMargin: 20
                        Layout.topMargin: 16; spacing: 8

                        Label {
                            text: "STRAVA"
                            font.pixelSize: 9; font.weight: Font.Black
                            color: textMuted; font.letterSpacing: 1.2
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: stravaInner.implicitHeight + 20
                            radius: 10; color: surface2
                            border.width: 1; border.color: borderCol

                            ColumnLayout {
                                id: stravaInner
                                anchors { fill: parent; margins: 12 }
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    Label {
                                        text: routeTab.stravaConnected ? "Подключено" : "Не подключено"
                                        font.pixelSize: 12; font.weight: Font.DemiBold
                                        color: routeTab.stravaConnected ? runColor : textMuted
                                        Layout.fillWidth: true
                                    }
                                    // Status dot
                                    Rectangle {
                                        width: 8; height: 8; radius: 4
                                        color: routeTab.stravaConnected ? runColor : borderCol
                                    }
                                }

                                Label {
                                    Layout.fillWidth: true
                                    text: routeTab.stravaConnected
                                        ? "Активности синхронизируются автоматически"
                                        : "Подключите аккаунт чтобы тренировки загружались сами"
                                    font.pixelSize: 10; color: textMuted; wrapMode: Text.Wrap
                                }

                                RowLayout {
                                    spacing: 6
                                    Rectangle {
                                        height: 28; width: stravaBtn.implicitWidth + 18; radius: 7
                                        color: routeTab.stravaConnected ? surface : "#FC4C02"
                                        border.width: routeTab.stravaConnected ? 1 : 0
                                        border.color: borderCol
                                        Label {
                                            id: stravaBtn
                                            anchors.centerIn: parent
                                            text: routeTab.stravaConnected ? "Отключить" : "Подключить Strava"
                                            font.pixelSize: 11; font.weight: Font.DemiBold
                                            color: routeTab.stravaConnected ? textMuted : "#fff"
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (routeTab.stravaConnected)
                                                    routeTab.disconnectStravaRequested()
                                                else if (!routeTab.stravaHasClientId)
                                                    routeTab.openStravaSettingsRequested()
                                                else
                                                    routeTab.connectStravaRequested()
                                            }
                                        }
                                    }
                                    Rectangle {
                                        visible: routeTab.stravaConnected
                                        height: 28; width: syncLbl.implicitWidth + 18; radius: 7
                                        color: surface2; border.width: 1; border.color: borderCol
                                        Label {
                                            id: syncLbl; anchors.centerIn: parent
                                            text: "Синхронизировать"; font.pixelSize: 11; color: accent
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: routeTab.syncStravaRequested() }
                                    }
                                }
                            }
                        }
                    }

                    // ── Generate form ──────────────────────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.leftMargin: 20; Layout.rightMargin: 20
                        Layout.topMargin: 16; spacing: 8

                        Label {
                            text: "СГЕНЕРИРОВАТЬ"
                            font.pixelSize: 9; font.weight: Font.Black
                            color: textMuted; font.letterSpacing: 1.2
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: genInner.implicitHeight + 20
                            radius: 10; color: surface2
                            border.width: 1; border.color: borderCol

                            ColumnLayout {
                                id: genInner
                                anchors { fill: parent; margins: 12 }
                                spacing: 10

                                // Lat/Lon
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
                                TextField {
                                    Layout.fillWidth: true; implicitHeight: 32; font.pixelSize: 12
                                    placeholderText: "парки, набережная, тихие улицы..."
                                    onTextChanged: routeTab.genPrefs = text
                                }

                                // Generate button
                                Rectangle {
                                    Layout.fillWidth: true; height: 34; radius: 8
                                    color: routeTab.isBusy ? borderCol : accent
                                    opacity: routeTab.isBusy ? 0.7 : 1.0
                                    RowLayout {
                                        anchors.centerIn: parent; spacing: 6
                                        BusyIndicator { width: 16; height: 16; visible: routeTab.isBusy; running: routeTab.isBusy }
                                        Label {
                                            text: routeTab.isBusy ? "Строю маршрут..." : "Сгенерировать"
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
                    }

                    // ── Saved routes ───────────────────────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.topMargin: 16; spacing: 0

                        RowLayout {
                            Layout.leftMargin: 20; Layout.rightMargin: 20; Layout.fillWidth: true
                            Label {
                                text: "СОХРАНЁННЫЕ"
                                font.pixelSize: 9; font.weight: Font.Black
                                color: textMuted; font.letterSpacing: 1.2
                            }
                        }

                        Item { height: 8 }

                        Repeater {
                            model: routeTab.routesModel
                            delegate: Rectangle {
                                width: parent.width; height: 64
                                color: routeTab.selectedRoute && routeTab.selectedRoute.id === modelData.id
                                       ? (dark ? "#16123a" : "#f5f3ff") : "transparent"

                                // Bottom separator
                                Rectangle {
                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 20; rightMargin: 20 }
                                    height: 1; color: borderCol; opacity: 0.7
                                }

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 20; rightMargin: 16 }
                                    spacing: 10
                                    Rectangle { width: 3; height: 36; radius: 2; color: accent }
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 2
                                        Label { text: modelData.name || "Маршрут"; font.pixelSize: 13; font.weight: Font.DemiBold; color: textPrimary; elide: Text.ElideRight; Layout.fillWidth: true }
                                        Label { text: (modelData.distanceKm || 0).toFixed(1) + " км"; font.pixelSize: 11; color: textMuted }
                                    }
                                    Rectangle {
                                        width: 26; height: 26; radius: 6
                                        color: surface2; border.width: 1; border.color: borderCol
                                        Label { anchors.centerIn: parent; text: "×"; font.pixelSize: 14; color: textMuted }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: routeTab.deleteRouteRequested(modelData.id) }
                                    }
                                }
                                MouseArea { anchors.fill: parent; z: -1; cursorShape: Qt.PointingHandCursor
                                    onClicked: routeTab.selectedRoute = modelData }
                            }
                        }

                        Label {
                            Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 20
                            visible: routeTab.routesModel.length === 0
                            text: "Маршрутов пока нет"
                            font.pixelSize: 12; color: textMuted
                        }

                        Item { height: 16 }
                    }
                }
            }
        }

        // ── Right: always-visible map + toolbar ───────────────────────────────
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true

            // The map always covers the full right area
            TileMap {
                id: theMap
                anchors.fill: parent
                dark:        routeTab.dark
                lineColor:   routeTab.accent
                routeCoords: routeTab.routeCoords
                centerLat:   routeTab.selectedRoute
                             ? (routeTab.selectedRoute.startLat || routeTab.defaultLat)
                             : routeTab.defaultLat
                centerLon:   routeTab.selectedRoute
                             ? (routeTab.selectedRoute.startLon || routeTab.defaultLon)
                             : routeTab.defaultLon
            }

            // ── Route info overlay (shown when route selected) ────────────────
            Rectangle {
                visible: !!routeTab.selectedRoute
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
                height: routeInfoRow.implicitHeight + 20
                radius: 10; color: surface + "ee"
                border.width: 1; border.color: borderCol

                RowLayout {
                    id: routeInfoRow
                    anchors { fill: parent; margins: 12 }
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Label {
                            text: routeTab.selectedRoute ? (routeTab.selectedRoute.name || "Маршрут") : ""
                            font.pixelSize: 15; font.weight: Font.Black; color: textPrimary
                        }
                        Label {
                            text: routeTab.selectedRoute
                                  ? ((routeTab.selectedRoute.distanceKm || 0).toFixed(1) + " км  ·  " + (routeTab.selectedRoute.description || ""))
                                  : ""
                            font.pixelSize: 11; color: textMuted; elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Open on OSM
                    Rectangle {
                        height: 30; width: osmLbl.implicitWidth + 16; radius: 7
                        color: surface2; border.width: 1; border.color: borderCol
                        Label { id: osmLbl; anchors.centerIn: parent; text: "Открыть на OSM"; font.pixelSize: 11; color: accent }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (routeTab.selectedRoute) {
                                    var lat = routeTab.selectedRoute.startLat || 55.75
                                    var lon = routeTab.selectedRoute.startLon || 37.62
                                    Qt.openUrlExternally("https://www.openstreetmap.org/?mlat=" + lat + "&mlon=" + lon + "&zoom=14")
                                }
                            }
                        }
                    }

                    // Close selection
                    Rectangle {
                        width: 30; height: 30; radius: 7
                        color: surface2; border.width: 1; border.color: borderCol
                        Label { anchors.centerIn: parent; text: "✕"; font.pixelSize: 13; color: textMuted }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { routeTab.selectedRoute = null; routeTab.routeCoords = [] } }
                    }
                }
            }

            // ── Edit toolbar (bottom of map) ──────────────────────────────────
            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: 12 }
                height: toolbarRow.implicitHeight + 16
                radius: 10; color: surface + "f0"
                border.width: 1; border.color: borderCol

                RowLayout {
                    id: toolbarRow
                    anchors { fill: parent; margins: 10 }
                    spacing: 8

                    // Draw mode toggle
                    Rectangle {
                        height: 34; width: drawLbl.implicitWidth + 18; radius: 8
                        color: theMap.editMode ? accent : surface2
                        border.width: 1; border.color: theMap.editMode ? accent : borderCol
                        Label {
                            id: drawLbl; anchors.centerIn: parent
                            text: theMap.editMode ? "Рисую…" : "Нарисовать маршрут"
                            font.pixelSize: 12; font.weight: Font.DemiBold
                            color: theMap.editMode ? "#fff" : textPrimary
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: theMap.editMode = !theMap.editMode }
                    }

                    // Undo last point
                    Rectangle {
                        visible: theMap.editMode && theMap.editWaypoints.length > 0
                        height: 34; width: undoLbl.implicitWidth + 18; radius: 8
                        color: surface2; border.width: 1; border.color: borderCol
                        Label { id: undoLbl; anchors.centerIn: parent; text: "← Отмена"; font.pixelSize: 12; color: textPrimary }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: theMap.removeLastWaypoint() }
                    }

                    // Clear all
                    Rectangle {
                        visible: theMap.editMode && theMap.editWaypoints.length > 0
                        height: 34; width: clearLbl.implicitWidth + 18; radius: 8
                        color: surface2; border.width: 1; border.color: borderCol
                        Label { id: clearLbl; anchors.centerIn: parent; text: "Очистить"; font.pixelSize: 12; color: textMuted }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: theMap.clearEditWaypoints() }
                    }

                    Item { Layout.fillWidth: true }

                    // Build route from waypoints
                    Rectangle {
                        visible: theMap.editWaypoints.length >= 2
                        height: 34; width: buildLbl.implicitWidth + 18; radius: 8
                        color: routeTab.isBusy ? borderCol : runColor
                        opacity: routeTab.isBusy ? 0.7 : 1.0
                        Label {
                            id: buildLbl; anchors.centerIn: parent
                            text: routeTab.isBusy ? "Строю…" : "Построить маршрут"
                            font.pixelSize: 12; font.weight: Font.DemiBold; color: "#fff"
                        }
                        MouseArea { anchors.fill: parent; enabled: !routeTab.isBusy; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var wps = []
                                for (var i = 0; i < theMap.editWaypoints.length; i++) {
                                    var wp = theMap.editWaypoints[i]
                                    wps.push([wp.lon, wp.lat])
                                }
                                routeTab.buildFromWaypointsRequested(wps, "Мой маршрут")
                                theMap.clearEditWaypoints()
                                theMap.editMode = false
                            }
                        }
                    }

                    // Hint when not editing
                    Label {
                        visible: !theMap.editMode
                        text: "Прокрутка для зума · Перетаскивание для перемещения"
                        font.pixelSize: 10; color: textMuted
                    }
                }
            }
        }
    }
}
