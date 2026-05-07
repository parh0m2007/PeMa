import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Shapes

// Vector body silhouette with clickable pain points.
// No PNG dependency — drawn entirely with QML primitives so it scales cleanly
// and matches the theme.
Item {
    id: root
    implicitWidth:  200
    implicitHeight: 340

    property var activeIds: ({})
    signal toggled(string id, string name)

    // Theme-aware silhouette colour (caller can override).
    property color silhouetteColor: "#cbd5e1"  // soft slate
    property color silhouetteEdge:  "#94a3b8"

    // ── Pain points (positioned over the silhouette) ──────────────────────────
    readonly property var dots: [
        { id: "head",      name: "Голова",         cx: 100, cy: 24,  r: 11 },
        { id: "neck",      name: "Шея",            cx: 100, cy: 50,  r: 7  },
        { id: "lshoulder", name: "Лев. плечо",     cx: 64,  cy: 64,  r: 9  },
        { id: "rshoulder", name: "Прав. плечо",    cx: 136, cy: 64,  r: 9  },
        { id: "chest",     name: "Грудь",          cx: 100, cy: 88,  r: 10 },
        { id: "lback",     name: "Поясница",       cx: 100, cy: 128, r: 10 },
        { id: "lelbow",    name: "Лев. локоть",    cx: 28,  cy: 110, r: 8  },
        { id: "relbow",    name: "Прав. локоть",   cx: 172, cy: 110, r: 8  },
        { id: "lwrist",    name: "Лев. запястье",  cx: 28,  cy: 160, r: 7  },
        { id: "rwrist",    name: "Прав. запястье", cx: 172, cy: 160, r: 7  },
        { id: "lhip",      name: "Лев. бедро",     cx: 80,  cy: 178, r: 9  },
        { id: "rhip",      name: "Прав. бедро",    cx: 120, cy: 178, r: 9  },
        { id: "lknee",     name: "Лев. колено",    cx: 81,  cy: 240, r: 9  },
        { id: "rknee",     name: "Прав. колено",   cx: 119, cy: 240, r: 9  },
        { id: "lshin",     name: "Лев. голень",    cx: 81,  cy: 280, r: 8  },
        { id: "rshin",     name: "Прав. голень",   cx: 119, cy: 280, r: 8  },
        { id: "lankle",    name: "Лев. лодыжка",   cx: 81,  cy: 318, r: 8  },
        { id: "rankle",    name: "Прав. лодыжка",  cx: 119, cy: 318, r: 8  },
    ]

    // ── Silhouette (composed of soft-cornered primitives) ─────────────────────
    Item {
        anchors.fill: parent
        antialiasing: true

        // Head
        Rectangle {
            x: 82; y: 6; width: 36; height: 36; radius: 18
            color: root.silhouetteColor
            border.width: 1; border.color: root.silhouetteEdge
            antialiasing: true
        }
        // Neck
        Rectangle {
            x: 92; y: 38; width: 16; height: 14
            color: root.silhouetteColor
            border.width: 0
        }
        // Upper torso (shoulders)
        Rectangle {
            x: 56; y: 50; width: 88; height: 60; radius: 14
            color: root.silhouetteColor
            border.width: 1; border.color: root.silhouetteEdge
            antialiasing: true
        }
        // Lower torso (waist tapering)
        Rectangle {
            x: 64; y: 100; width: 72; height: 44
            color: root.silhouetteColor
            border.width: 0
        }
        // Pelvis / hips
        Rectangle {
            x: 56; y: 138; width: 88; height: 44; radius: 14
            color: root.silhouetteColor
            border.width: 1; border.color: root.silhouetteEdge
            antialiasing: true
        }
        // Left arm
        Rectangle {
            x: 18; y: 58; width: 20; height: 116; radius: 10
            color: root.silhouetteColor
            border.width: 1; border.color: root.silhouetteEdge
            antialiasing: true
        }
        // Right arm
        Rectangle {
            x: 162; y: 58; width: 20; height: 116; radius: 10
            color: root.silhouetteColor
            border.width: 1; border.color: root.silhouetteEdge
            antialiasing: true
        }
        // Left leg
        Rectangle {
            x: 64; y: 170; width: 32; height: 162; radius: 12
            color: root.silhouetteColor
            border.width: 1; border.color: root.silhouetteEdge
            antialiasing: true
        }
        // Right leg
        Rectangle {
            x: 104; y: 170; width: 32; height: 162; radius: 12
            color: root.silhouetteColor
            border.width: 1; border.color: root.silhouetteEdge
            antialiasing: true
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
                     : dotItem.hovered ? Qt.rgba(0.86, 0.15, 0.15, 0.32)
                     : Qt.rgba(0, 0, 0, 0.05)

                border.color: dotItem.active  ? "#991b1b"
                            : dotItem.hovered ? Qt.rgba(0.86, 0.15, 0.15, 0.7)
                            : Qt.rgba(0, 0, 0, 0.18)
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
