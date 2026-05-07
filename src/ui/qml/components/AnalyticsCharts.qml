import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Weekly + monthly bar charts for the Analytics tab
Item {
    id: charts

    // Theme
    property color surface:     "#ffffff"
    property color surface2:    "#f6f8fa"
    property color borderCol:   "#dde3eb"
    property color textPrimary: "#0d1117"
    property color textMuted:   "#57606a"
    property color accent:      "#6366f1"
    property color runColor:    "#22c55e"
    property bool  dark: false

    // Data
    property var weeklyVolume:  []   // [{weekStart, distance, duration, count}]
    property var monthlyVolume: []   // [{month, distance, duration, count}]

    // Which metric to plot
    property string metric: "distance"   // "distance" | "duration" | "count"

    implicitHeight: chartsCol.implicitHeight

    Column {
        id: chartsCol
        anchors { left: parent.left; right: parent.right }
        spacing: 16

        // ── Weekly chart ──────────────────────────────────────────────────────
        Rectangle {
            width: parent.width; height: 180
            radius: 12; color: charts.surface
            border.width: 1; border.color: charts.borderCol

            ColumnLayout {
                anchors { fill: parent; margins: 14 }
                spacing: 8

                RowLayout {
                    Label {
                        text: "ОБЪЁМ ПО НЕДЕЛЯМ"
                        font.pixelSize: 10; font.weight: Font.Black
                        color: charts.textMuted; font.letterSpacing: 1
                    }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: charts.metric === "distance" ? "км"
                            : charts.metric === "duration" ? "мин" : "трен."
                        font.pixelSize: 10; color: charts.textMuted
                    }
                }

                // Bar chart area
                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true

                    Row {
                        anchors.fill: parent
                        spacing: 4

                        Repeater {
                            model: charts.weeklyVolume

                            delegate: Item {
                                width: (charts.weeklyVolume.length > 0)
                                       ? (parent.width - 4 * (charts.weeklyVolume.length - 1)) / charts.weeklyVolume.length
                                       : 0
                                height: parent.height

                                property real rawVal: {
                                    if (charts.metric === "distance") return modelData.distance || 0
                                    if (charts.metric === "duration") return modelData.duration || 0
                                    return modelData.count || 0
                                }
                                property real maxVal: {
                                    var mx = 0.001
                                    for (var i = 0; i < charts.weeklyVolume.length; i++) {
                                        var v = charts.metric === "distance" ? (charts.weeklyVolume[i].distance || 0)
                                              : charts.metric === "duration" ? (charts.weeklyVolume[i].duration || 0)
                                              : (charts.weeklyVolume[i].count || 0)
                                        if (v > mx) mx = v
                                    }
                                    return mx
                                }
                                property real frac: rawVal / maxVal

                                // Bar
                                Rectangle {
                                    width: parent.width
                                    height: Math.max(2, parent.height * 0.75 * frac)
                                    anchors.bottom: weekLabel.top; anchors.bottomMargin: 4
                                    radius: 3
                                    color: charts.accent
                                    opacity: 0.85

                                    Behavior on height { NumberAnimation { duration: 400 } }

                                    // Value label on top of bar (only if bar tall enough)
                                    Label {
                                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.top; bottomMargin: 2 }
                                        visible: parent.height > 20
                                        text: charts.metric === "distance"
                                              ? Number(rawVal).toFixed(0)
                                              : String(Math.round(rawVal))
                                        font.pixelSize: 8; color: charts.textMuted
                                    }
                                }

                                // Week label
                                Label {
                                    id: weekLabel
                                    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                                    text: {
                                        var s = modelData.weekStart || ""
                                        // show only MM/DD
                                        if (s.length >= 10) return s.substring(5, 10).replace("-", "/")
                                        return s
                                    }
                                    font.pixelSize: 7; color: charts.textMuted
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }

                        // Empty state
                        Label {
                            visible: charts.weeklyVolume.length === 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Нет данных"
                            font.pixelSize: 12; color: charts.textMuted
                        }
                    }
                }
            }
        }

        // ── Monthly chart ─────────────────────────────────────────────────────
        Rectangle {
            width: parent.width; height: 180
            radius: 12; color: charts.surface
            border.width: 1; border.color: charts.borderCol

            ColumnLayout {
                anchors { fill: parent; margins: 14 }
                spacing: 8

                RowLayout {
                    Label {
                        text: "ОБЪЁМ ПО МЕСЯЦАМ"
                        font.pixelSize: 10; font.weight: Font.Black
                        color: charts.textMuted; font.letterSpacing: 1
                    }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: charts.metric === "distance" ? "км"
                            : charts.metric === "duration" ? "мин" : "трен."
                        font.pixelSize: 10; color: charts.textMuted
                    }
                }

                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true

                    Row {
                        anchors.fill: parent
                        spacing: 6

                        Repeater {
                            model: charts.monthlyVolume

                            delegate: Item {
                                width: (charts.monthlyVolume.length > 0)
                                       ? (parent.width - 6 * (charts.monthlyVolume.length - 1)) / charts.monthlyVolume.length
                                       : 0
                                height: parent.height

                                property real rawVal: {
                                    if (charts.metric === "distance") return modelData.distance || 0
                                    if (charts.metric === "duration") return modelData.duration || 0
                                    return modelData.count || 0
                                }
                                property real maxVal: {
                                    var mx = 0.001
                                    for (var i = 0; i < charts.monthlyVolume.length; i++) {
                                        var v = charts.metric === "distance" ? (charts.monthlyVolume[i].distance || 0)
                                              : charts.metric === "duration" ? (charts.monthlyVolume[i].duration || 0)
                                              : (charts.monthlyVolume[i].count || 0)
                                        if (v > mx) mx = v
                                    }
                                    return mx
                                }
                                property real frac: rawVal / maxVal

                                Rectangle {
                                    width: parent.width
                                    height: Math.max(2, parent.height * 0.75 * frac)
                                    anchors.bottom: monthLabel.top; anchors.bottomMargin: 4
                                    radius: 3
                                    color: charts.runColor
                                    opacity: 0.85

                                    Behavior on height { NumberAnimation { duration: 400 } }

                                    Label {
                                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.top; bottomMargin: 2 }
                                        visible: parent.height > 20
                                        text: charts.metric === "distance"
                                              ? Number(rawVal).toFixed(0)
                                              : String(Math.round(rawVal))
                                        font.pixelSize: 8; color: charts.textMuted
                                    }
                                }

                                Label {
                                    id: monthLabel
                                    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                                    text: {
                                        var s = modelData.month || ""
                                        // "2026-03" → "мар" etc.
                                        var months = ["янв","фев","мар","апр","май","июн","июл","авг","сен","окт","ноя","дек"]
                                        var parts = s.split("-")
                                        if (parts.length >= 2) {
                                            var m = parseInt(parts[1]) - 1
                                            return months[m] || s
                                        }
                                        return s
                                    }
                                    font.pixelSize: 8; color: charts.textMuted
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }

                        Label {
                            visible: charts.monthlyVolume.length === 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Нет данных"
                            font.pixelSize: 12; color: charts.textMuted
                        }
                    }
                }
            }
        }
    }
}
