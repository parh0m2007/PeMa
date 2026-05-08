import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property string message: ""
    signal dismissed()

    visible: message.length > 0
    height: visible ? 42 : 0
    radius: 10
    color: "#fef2f2"
    border.width: 1
    border.color: "#fecaca"

    Behavior on height { NumberAnimation { duration: 150 } }

    RowLayout {
        anchors { fill: parent; leftMargin: 14; rightMargin: 8; topMargin: 6; bottomMargin: 6 }
        spacing: 10

        Label {
            text: "⚠"
            font.pixelSize: 14
            color: "#ef4444"
        }

        Label {
            Layout.fillWidth: true
            text: root.message
            color: "#b91c1c"
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        RoundButton {
            width: 26; height: 26; radius: 6
            flat: true
            text: "✕"
            font.pixelSize: 12
            onClicked: root.dismissed()
        }
    }
}
