import QtQuick
import QtQuick.Controls

/**
 * TileMap — real OpenStreetMap tiles + route polyline overlay.
 * Pure QML, no QtLocation needed. Supports pan (drag) and zoom (scroll wheel).
 */
Item {
    id: tileMap
    clip: true

    // ── Public API ────────────────────────────────────────────────────────────
    property double centerLat:  55.7558   // Moscow default
    property double centerLon:  37.6173
    property int    zoom:        14
    property var    routeCoords: []       // [[lon, lat], …]
    property color  lineColor:  "#6366f1"
    property bool   dark:        false
    // Tile server base – defaults to local proxy (avoids OSM 418 / UA block)
    property string tileServer: "http://localhost:8000/api/tiles"

    // ── Edit mode ─────────────────────────────────────────────────────────────
    property bool editMode: false        // when true, clicks add waypoints
    property var  editWaypoints: []      // [{lat, lon}, …]
    signal waypointAdded()               // emitted after each click-add

    function addWaypoint(lat, lon) {
        var wps = editWaypoints.slice()
        wps.push({ lat: lat, lon: lon })
        editWaypoints = wps
        waypointAdded()
        routeCanvas.requestPaint()
    }
    function removeLastWaypoint() {
        if (editWaypoints.length === 0) return
        var wps = editWaypoints.slice(0, editWaypoints.length - 1)
        editWaypoints = wps
        routeCanvas.requestPaint()
    }
    function clearEditWaypoints() {
        editWaypoints = []
        routeCanvas.requestPaint()
    }

    // Inverse mercator: screen pixel → {lat, lon}
    function screenToLatLon(sx, sy) {
        var cx = _lonToWorld(centerLon)
        var cy = _latToWorld(centerLat)
        var wx = sx - width / 2 + cx
        var wy = sy - height / 2 + cy
        var lon = wx * 360 / _scale() - 180
        var lat = _worldYToLat(wy)
        return { lat: lat, lon: lon }
    }

    // ── Tile state ────────────────────────────────────────────────────────────
    property var    tileData:   []

    // ── Mercator helpers ──────────────────────────────────────────────────────
    function _scale() { return Math.pow(2, zoom) * 256 }

    function _lonToWorld(lon) {
        return (lon + 180) / 360 * _scale()
    }
    function _latToWorld(lat) {
        var s = Math.sin(lat * Math.PI / 180)
        return (0.5 - Math.log((1 + s) / (1 - s)) / (4 * Math.PI)) * _scale()
    }

    // World pixel → screen pixel (relative to this Item's top-left)
    function _worldToScreen(wx, wy) {
        var cx = _lonToWorld(centerLon)
        var cy = _latToWorld(centerLat)
        return Qt.point(wx - cx + width / 2, wy - cy + height / 2)
    }

    function latLonToScreen(lat, lon) {
        return _worldToScreen(_lonToWorld(lon), _latToWorld(lat))
    }

    // Inverse mercator: world pixel Y → latitude
    function _worldYToLat(wy) {
        var n = Math.PI - 2 * Math.PI * wy / _scale()
        return 180 / Math.PI * Math.atan(Math.sinh(n))
    }

    // ── Auto-fit to route bounding box ────────────────────────────────────────
    function fitRoute() {
        if (!routeCoords || routeCoords.length < 2) { _updateTiles(); return }

        var minLat = routeCoords[0][1], maxLat = routeCoords[0][1]
        var minLon = routeCoords[0][0], maxLon = routeCoords[0][0]
        for (var i = 1; i < routeCoords.length; i++) {
            if (routeCoords[i][1] < minLat) minLat = routeCoords[i][1]
            if (routeCoords[i][1] > maxLat) maxLat = routeCoords[i][1]
            if (routeCoords[i][0] < minLon) minLon = routeCoords[i][0]
            if (routeCoords[i][0] > maxLon) maxLon = routeCoords[i][0]
        }
        centerLat = (minLat + maxLat) / 2
        centerLon = (minLon + maxLon) / 2

        // Walk zoom levels from 16 down until route fits with padding
        for (var z = 16; z >= 8; z--) {
            zoom = z
            var tl = latLonToScreen(maxLat, minLon)
            var br = latLonToScreen(minLat, maxLon)
            var pad = 48
            if (tl.x >= pad && br.x <= width - pad && tl.y >= pad && br.y <= height - pad)
                break
        }
        _updateTiles()
        routeCanvas.requestPaint()
    }

    // ── Tile grid ─────────────────────────────────────────────────────────────
    function _updateTiles() {
        if (width <= 0 || height <= 0) return
        var maxTile = Math.pow(2, zoom)
        var cx = _lonToWorld(centerLon)
        var cy = _latToWorld(centerLat)
        var tilesX = Math.ceil(width  / 256) + 3
        var tilesY = Math.ceil(height / 256) + 3
        var ctx_ = Math.floor(cx / 256)
        var cty_ = Math.floor(cy / 256)
        var startX = ctx_ - Math.floor(tilesX / 2) - 1
        var startY = cty_ - Math.floor(tilesY / 2) - 1

        var tiles = []
        for (var ty = startY; ty <= startY + tilesY + 1; ty++) {
            for (var tx = startX; tx <= startX + tilesX + 1; tx++) {
                var sx = tx * 256 - cx + width / 2
                var sy = ty * 256 - cy + height / 2
                var vtx = ((tx % maxTile) + maxTile) % maxTile
                var vty = Math.max(0, Math.min(maxTile - 1, ty))
                tiles.push({
                    x:   sx,
                    y:   sy,
                    url: tileMap.tileServer + "/" + zoom + "/" + vtx + "/" + vty
                })
            }
        }
        tileData = tiles
    }

    // ── Reactivity ────────────────────────────────────────────────────────────
    onWidthChanged:         Qt.callLater(_updateTiles)
    onHeightChanged:        Qt.callLater(_updateTiles)
    onCenterLatChanged:     { Qt.callLater(_updateTiles); routeCanvas.requestPaint() }
    onCenterLonChanged:     { Qt.callLater(_updateTiles); routeCanvas.requestPaint() }
    onZoomChanged:          { Qt.callLater(_updateTiles); routeCanvas.requestPaint() }
    onRouteCoordsChanged:   Qt.callLater(fitRoute)
    Component.onCompleted:  Qt.callLater(fitRoute)

    // ── Tile image layer ──────────────────────────────────────────────────────
    // Gray base fill (shown while tiles load / attribution)
    Rectangle {
        anchors.fill: parent
        color: tileMap.dark ? "#2d3748" : "#e8ecef"
    }

    Repeater {
        model: tileMap.tileData
        Image {
            x: modelData.x; y: modelData.y
            width: 256; height: 256
            source: modelData.url
            cache: true
            smooth: true
            // Fade-in when loaded
            opacity: 0
            onStatusChanged: if (status === Image.Ready) fadeIn.start()
            NumberAnimation on opacity { id: fadeIn; to: 1; duration: 180 }
        }
    }

    // ── Route Canvas overlay ──────────────────────────────────────────────────
    Canvas {
        id: routeCanvas
        anchors.fill: parent
        z: 10

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            // ── Saved route ───────────────────────────────────────────────────
            if (tileMap.routeCoords && tileMap.routeCoords.length >= 2) {
                var p0 = tileMap.latLonToScreen(tileMap.routeCoords[0][1], tileMap.routeCoords[0][0])

                // White halo
                ctx.strokeStyle = "white"; ctx.lineWidth = 6; ctx.lineCap = "round"
                ctx.lineJoin = "round"; ctx.globalAlpha = 0.7
                ctx.beginPath(); ctx.moveTo(p0.x, p0.y)
                for (var i = 1; i < tileMap.routeCoords.length; i++) {
                    var p = tileMap.latLonToScreen(tileMap.routeCoords[i][1], tileMap.routeCoords[i][0])
                    ctx.lineTo(p.x, p.y)
                }
                ctx.stroke()

                // Colored line
                ctx.strokeStyle = tileMap.lineColor; ctx.lineWidth = 3.5; ctx.globalAlpha = 1.0
                ctx.beginPath(); ctx.moveTo(p0.x, p0.y)
                for (var j = 1; j < tileMap.routeCoords.length; j++) {
                    var q = tileMap.latLonToScreen(tileMap.routeCoords[j][1], tileMap.routeCoords[j][0])
                    ctx.lineTo(q.x, q.y)
                }
                ctx.stroke()

                // Start dot
                ctx.strokeStyle = "white"; ctx.lineWidth = 2.5; ctx.fillStyle = "#22c55e"
                ctx.beginPath(); ctx.arc(p0.x, p0.y, 7, 0, Math.PI * 2); ctx.fill(); ctx.stroke()

                // End dot
                var pn = tileMap.latLonToScreen(
                    tileMap.routeCoords[tileMap.routeCoords.length - 1][1],
                    tileMap.routeCoords[tileMap.routeCoords.length - 1][0])
                ctx.fillStyle = tileMap.lineColor
                ctx.beginPath(); ctx.arc(pn.x, pn.y, 5, 0, Math.PI * 2); ctx.fill(); ctx.stroke()
            }

            // ── Edit waypoints preview ────────────────────────────────────────
            var wps = tileMap.editWaypoints
            if (wps && wps.length >= 1) {
                // Dashed connecting line
                ctx.setLineDash([6, 4])
                ctx.strokeStyle = tileMap.lineColor; ctx.lineWidth = 2.5
                ctx.globalAlpha = 0.85; ctx.lineCap = "round"; ctx.lineJoin = "round"
                ctx.beginPath()
                var ep0 = tileMap.latLonToScreen(wps[0].lat, wps[0].lon)
                ctx.moveTo(ep0.x, ep0.y)
                for (var wi = 1; wi < wps.length; wi++) {
                    var ep = tileMap.latLonToScreen(wps[wi].lat, wps[wi].lon)
                    ctx.lineTo(ep.x, ep.y)
                }
                ctx.stroke()
                ctx.setLineDash([])

                // Waypoint dots
                for (var di = 0; di < wps.length; di++) {
                    var dp = tileMap.latLonToScreen(wps[di].lat, wps[di].lon)
                    ctx.globalAlpha = 1.0
                    // White ring
                    ctx.fillStyle = "white"; ctx.strokeStyle = tileMap.lineColor; ctx.lineWidth = 2
                    ctx.beginPath(); ctx.arc(dp.x, dp.y, 8, 0, Math.PI * 2); ctx.fill(); ctx.stroke()
                    // Number label
                    ctx.fillStyle = tileMap.lineColor; ctx.font = "bold 9px sans-serif"
                    ctx.textAlign = "center"; ctx.textBaseline = "middle"
                    ctx.fillText(String(di + 1), dp.x, dp.y)
                }
            }
        }
    }

    // ── OSM attribution (required by tile policy) ─────────────────────────────
    Rectangle {
        anchors { right: parent.right; bottom: parent.bottom; margins: 0 }
        width: attribLabel.implicitWidth + 10; height: 16
        color: "#ffffffcc"; z: 20
        Label {
            id: attribLabel
            anchors.centerIn: parent
            text: "© OpenStreetMap contributors"
            font.pixelSize: 8; color: "#333"
        }
        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: Qt.openUrlExternally("https://www.openstreetmap.org/copyright")
        }
    }

    // ── Zoom buttons ──────────────────────────────────────────────────────────
    Column {
        anchors { left: parent.left; top: parent.top; margins: 10 }
        spacing: 2; z: 20

        Rectangle {
            width: 30; height: 30; radius: 6
            color: zoomInMa.containsMouse ? "#f0f0f0" : "white"
            border.width: 1; border.color: "#ccc"
            Label { anchors.centerIn: parent; text: "+"; font.pixelSize: 18; font.weight: Font.Bold; color: "#333" }
            MouseArea { id: zoomInMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: tileMap.zoom = Math.min(18, tileMap.zoom + 1) }
        }
        Rectangle {
            width: 30; height: 30; radius: 6
            color: zoomOutMa.containsMouse ? "#f0f0f0" : "white"
            border.width: 1; border.color: "#ccc"
            Label { anchors.centerIn: parent; text: "−"; font.pixelSize: 18; font.weight: Font.Bold; color: "#333" }
            MouseArea { id: zoomOutMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: tileMap.zoom = Math.max(8, tileMap.zoom - 1) }
        }
    }

    // ── Pan & scroll ──────────────────────────────────────────────────────────
    property real   _dragX:       0
    property real   _dragY:       0
    property double _dragLat:     0
    property double _dragLon:     0

    MouseArea {
        anchors.fill: parent
        z: 15
        cursorShape: tileMap.editMode ? Qt.CrossCursor : Qt.ArrowCursor

        // Track drag start (only used when NOT in edit mode)
        property bool _didDrag: false

        onPressed: function(e) {
            _didDrag = false
            tileMap._dragX   = e.x
            tileMap._dragY   = e.y
            tileMap._dragLat = tileMap.centerLat
            tileMap._dragLon = tileMap.centerLon
        }
        onPositionChanged: function(e) {
            if (!pressed) return
            if (tileMap.editMode) return   // no panning in edit mode
            var dx = e.x - tileMap._dragX
            var dy = e.y - tileMap._dragY
            if (Math.abs(dx) > 3 || Math.abs(dy) > 3) _didDrag = true
            var sc = tileMap._scale()
            tileMap.centerLon = tileMap._dragLon - dx * 360 / sc
            var newWy = tileMap._latToWorld(tileMap._dragLat) - dy
            tileMap.centerLat = tileMap._worldYToLat(newWy)
        }
        onClicked: function(e) {
            if (!tileMap.editMode) return
            var ll = tileMap.screenToLatLon(e.x, e.y)
            tileMap.addWaypoint(ll.lat, ll.lon)
        }
        onWheel: function(e) {
            if (e.angleDelta.y > 0) tileMap.zoom = Math.min(18, tileMap.zoom + 1)
            else                    tileMap.zoom = Math.max(8,  tileMap.zoom - 1)
        }

        propagateComposedEvents: true
    }

    // Edit mode indicator label (top-right)
    Rectangle {
        visible: tileMap.editMode
        anchors { top: parent.top; right: parent.right; margins: 8 }
        height: 24; width: editLabel.implicitWidth + 16; radius: 6
        color: tileMap.lineColor; z: 25
        Label {
            id: editLabel
            anchors.centerIn: parent
            text: "Режим рисования · " + tileMap.editWaypoints.length + " точек"
            font.pixelSize: 10; font.weight: Font.DemiBold; color: "#fff"
        }
    }
}
