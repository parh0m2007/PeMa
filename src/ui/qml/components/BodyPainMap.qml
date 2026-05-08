import QtQuick
import QtQuick.Controls.Basic

/**
 * Vector body silhouette drawn as one continuous Canvas path.
 * Arms connect to shoulders naturally via bezier curves.
 * Clickable pain-point dots overlay.
 */
Item {
    id: root
    implicitWidth:  200
    implicitHeight: 340

    property var   activeIds: ({})
    signal toggled(string id, string name)

    property color silhouetteColor: "#cbd5e1"
    property color silhouetteEdge:  "#94a3b8"

    // Repaint when theme changes
    onSilhouetteColorChanged: silhouetteCanvas.requestPaint()
    onSilhouetteEdgeChanged:  silhouetteCanvas.requestPaint()

    // ── Pain point definitions ────────────────────────────────────────────────
    readonly property var dots: [
        { id: "head",      name: "Голова",          cx: 100, cy: 22,  r: 11 },
        { id: "neck",      name: "Шея",             cx: 100, cy: 50,  r: 7  },
        { id: "lshoulder", name: "Лев. плечо",      cx: 50,  cy: 62,  r: 9  },
        { id: "rshoulder", name: "Прав. плечо",     cx: 150, cy: 62,  r: 9  },
        { id: "chest",     name: "Грудь",           cx: 100, cy: 92,  r: 10 },
        { id: "lback",     name: "Поясница",        cx: 100, cy: 132, r: 10 },
        { id: "lelbow",    name: "Лев. локоть",     cx: 24,  cy: 122, r: 8  },
        { id: "relbow",    name: "Прав. локоть",    cx: 176, cy: 122, r: 8  },
        { id: "lwrist",    name: "Лев. запястье",   cx: 22,  cy: 168, r: 7  },
        { id: "rwrist",    name: "Прав. запястье",  cx: 178, cy: 168, r: 7  },
        { id: "lhip",      name: "Лев. бедро",      cx: 72,  cy: 175, r: 9  },
        { id: "rhip",      name: "Прав. бедро",     cx: 128, cy: 175, r: 9  },
        { id: "lknee",     name: "Лев. колено",     cx: 78,  cy: 238, r: 9  },
        { id: "rknee",     name: "Прав. колено",    cx: 122, cy: 238, r: 9  },
        { id: "lshin",     name: "Лев. голень",     cx: 76,  cy: 274, r: 8  },
        { id: "rshin",     name: "Прав. голень",    cx: 124, cy: 274, r: 8  },
        { id: "lankle",    name: "Лев. лодыжка",    cx: 76,  cy: 308, r: 8  },
        { id: "rankle",    name: "Прав. лодыжка",   cx: 124, cy: 308, r: 8  },
    ]

    // ── Canvas silhouette ─────────────────────────────────────────────────────
    Canvas {
        id: silhouetteCanvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            ctx.fillStyle   = root.silhouetteColor
            ctx.strokeStyle = root.silhouetteEdge
            ctx.lineWidth   = 1.5
            ctx.lineJoin    = "round"
            ctx.lineCap     = "round"

            // ── Head ──────────────────────────────────────────────────────────
            ctx.beginPath()
            ctx.arc(100, 22, 18, 0, Math.PI * 2)
            ctx.fill()
            ctx.stroke()

            // ── Body: one continuous clockwise path ───────────────────────────
            // Starting at left side of neck, going around the whole figure.
            // Arms connect to shoulders via bezier — no gaps.
            ctx.beginPath()

            ctx.moveTo(92, 38)      // left neck, top

            // Left shoulder flowing into left arm
            ctx.bezierCurveTo(86, 40, 58, 48, 44, 60)   // shoulder slope
            ctx.bezierCurveTo(36, 68, 22, 96, 18, 122)  // upper arm outer
            ctx.bezierCurveTo(16, 136, 16, 150, 18, 164) // elbow curve
            ctx.lineTo(18, 174)
            ctx.bezierCurveTo(18, 180, 28, 182, 32, 176) // wrist/hand

            // Up the inner arm
            ctx.lineTo(36, 140)
            ctx.bezierCurveTo(40, 116, 48, 100, 56, 92)  // inner arm → torso

            // Left torso side: slight waist taper then hip
            ctx.bezierCurveTo(60, 84, 62, 104, 62, 124)
            ctx.bezierCurveTo(62, 140, 60, 152, 60, 164)
            ctx.bezierCurveTo(58, 172, 60, 178, 66, 180) // left hip

            // Left leg outer
            ctx.lineTo(64, 298)
            ctx.bezierCurveTo(64, 308, 68, 316, 76, 318) // ankle
            ctx.lineTo(90, 318)
            ctx.bezierCurveTo(96, 318, 98, 312, 98, 304) // foot inner

            // Left leg inner up
            ctx.lineTo(98, 182)

            // Crotch
            ctx.bezierCurveTo(98, 170, 100, 166, 102, 170)

            // Right leg inner down
            ctx.lineTo(102, 304)
            ctx.bezierCurveTo(102, 312, 104, 318, 110, 318) // right ankle inner
            ctx.lineTo(124, 318)
            ctx.bezierCurveTo(132, 316, 136, 308, 136, 298) // right ankle outer

            // Right leg outer up
            ctx.lineTo(134, 180)
            ctx.bezierCurveTo(140, 178, 142, 172, 140, 164) // right hip

            // Right torso side
            ctx.bezierCurveTo(140, 152, 138, 140, 138, 124)
            ctx.bezierCurveTo(138, 104, 140, 84, 144, 92)

            // Right inner arm → shoulder
            ctx.bezierCurveTo(152, 100, 160, 116, 164, 140)
            ctx.lineTo(168, 176)
            ctx.bezierCurveTo(172, 182, 182, 180, 182, 174)

            // Right wrist outer, up the arm
            ctx.lineTo(182, 164)
            ctx.bezierCurveTo(184, 150, 184, 136, 182, 122)
            ctx.bezierCurveTo(178, 96, 164, 68, 156, 60)   // upper arm outer

            // Right shoulder flowing into neck
            ctx.bezierCurveTo(142, 48, 114, 40, 108, 38)

            ctx.closePath()
            ctx.fill()
            ctx.stroke()
        }
    }

    // ── Pain dots overlay ─────────────────────────────────────────────────────
    Repeater {
        model: root.dots
        delegate: Item {
            id: dotItem
            x: modelData.cx - modelData.r - 6
            y: modelData.cy - modelData.r - 6
            width:  (modelData.r + 6) * 2
            height: (modelData.r + 6) * 2

            property bool active:  !!root.activeIds[modelData.id]
            property bool hovered: false

            Rectangle {
                anchors.centerIn: parent
                width:  modelData.r * 2
                height: modelData.r * 2
                radius: modelData.r

                color: dotItem.active  ? "#dc2626"
                     : dotItem.hovered ? Qt.rgba(0.86, 0.15, 0.15, 0.28)
                     : Qt.rgba(0, 0, 0, 0.04)

                border.color: dotItem.active  ? "#991b1b"
                            : dotItem.hovered ? Qt.rgba(0.86, 0.15, 0.15, 0.65)
                            : Qt.rgba(0, 0, 0, 0.15)
                border.width: dotItem.active ? 2 : 1
                antialiasing: true

                Behavior on color { ColorAnimation { duration: 100 } }

                SequentialAnimation on scale {
                    running: dotItem.active; loops: 1
                    NumberAnimation { to: 1.35; duration: 130 }
                    NumberAnimation { to: 1.0;  duration: 100 }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape:  Qt.PointingHandCursor
                onEntered: dotItem.hovered = true
                onExited:  dotItem.hovered = false
                onClicked: root.toggled(modelData.id, modelData.name)
            }

            ToolTip.visible: dotItem.hovered
            ToolTip.text:    modelData.name
            ToolTip.delay:   250
        }
    }
}
