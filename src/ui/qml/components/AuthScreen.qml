import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Full-screen auth overlay — shown whenever workoutStore.isLoggedIn === false
Rectangle {
    id: root

    // ── Colours (inherit from ApplicationWindow palette via parent bindings) ──
    property color bg:          "#0d1117"
    property color surface:     "#161b22"
    property color surface2:    "#21262d"
    property color borderCol:   "#30363d"
    property color textPrimary: "#e6edf3"
    property color textMuted:   "#8b949e"
    property color accent:      "#6366f1"
    property color runColor:    "#22c55e"

    color: Qt.rgba(0, 0, 0, 0.72)

    // ── Tab state ─────────────────────────────────────────────────────────────
    property int  tabIndex: 0   // 0 = login, 1 = register
    property string selectedRole: ""   // "athlete" | "coach"

    // ── Reset helpers ─────────────────────────────────────────────────────────
    function resetLogin() {
        loginEmail.text    = ""
        loginPassword.text = ""
    }
    function resetRegister() {
        regName.text     = ""
        regEmail.text    = ""
        regPassword.text = ""
        selectedRole     = ""
    }

    Connections {
        target: workoutStore
        function onLoginFailed(error) {
            // errors are already surfaced via authError property
        }
        function onLoginSucceeded() {
            resetLogin()
            resetRegister()
        }
    }

    // ── Centre card ───────────────────────────────────────────────────────────
    Rectangle {
        anchors.centerIn: parent
        width: 420
        height: cardContent.implicitHeight + 48 +
                (workoutStore.authError.length > 0 ? errRow.implicitHeight + 30 : 0)
        Behavior on height { NumberAnimation { duration: 150 } }
        radius: 18
        color: surface
        border.width: 1
        border.color: borderCol

        // subtle top glow
        layer.enabled: true

        ColumnLayout {
            id: cardContent
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 24 }
            spacing: 0

            // ── Logo & app name ───────────────────────────────────────────────
            Item { height: 28 }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10
                Rectangle {
                    width: 38; height: 38; radius: 10; color: accent
                    Label {
                        anchors.centerIn: parent; text: "S"
                        font.pixelSize: 20; font.weight: Font.Black; color: "#fff"
                    }
                }
                Label {
                    text: "PeMa"
                    font.pixelSize: 22; font.weight: Font.Black
                    color: textPrimary; font.letterSpacing: -0.5
                }
            }

            Item { height: 6 }
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: "Управление тренировками"
                font.pixelSize: 12; color: textMuted
            }
            Item { height: 20 }

            // ── Tab switcher ──────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; height: 38; radius: 10; color: surface2
                RowLayout {
                    anchors { fill: parent; margins: 4 }
                    spacing: 4
                    Repeater {
                        model: ["Войти", "Регистрация"]
                        delegate: Rectangle {
                            Layout.fillWidth: true; height: parent.height; radius: 8
                            color: root.tabIndex === index ? surface : "transparent"
                            Behavior on color { ColorAnimation { duration: 140 } }
                            border.width: root.tabIndex === index ? 1 : 0
                            border.color: borderCol
                            Label {
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: 13
                                font.weight: root.tabIndex === index ? Font.DemiBold : Font.Normal
                                color: root.tabIndex === index ? textPrimary : textMuted
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root.tabIndex = index
                            }
                        }
                    }
                }
            }

            Item { height: 18 }

            // ── LOGIN form ────────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; spacing: 10
                visible: root.tabIndex === 0

                Label { text: "Email"; font.pixelSize: 12; font.weight: Font.DemiBold; color: textMuted }
                TextField {
                    id: loginEmail
                    Layout.fillWidth: true; implicitHeight: 40
                    placeholderText: "you@example.com"
                    inputMethodHints: Qt.ImhEmailCharactersOnly
                    onAccepted: loginPassword.forceActiveFocus()
                }

                Label { text: "Пароль"; font.pixelSize: 12; font.weight: Font.DemiBold; color: textMuted }
                TextField {
                    id: loginPassword
                    Layout.fillWidth: true; implicitHeight: 40
                    placeholderText: "••••••••"
                    echoMode: TextInput.Password
                    onAccepted: doLogin()
                }

                Item { height: 4 }

                Button {
                    Layout.fillWidth: true; implicitHeight: 42; highlighted: true
                    enabled: !workoutStore.busy
                    background: Rectangle {
                        radius: 10
                        color: parent.enabled ? (parent.hovered ? "#4f46e5" : accent) : "#2d2d50"
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    contentItem: RowLayout {
                        spacing: 8; anchors.centerIn: parent
                        BusyIndicator {
                            visible: workoutStore.busy; running: workoutStore.busy
                            implicitWidth: 18; implicitHeight: 18
                            palette.dark: "#fff"
                        }
                        Label {
                            text: workoutStore.busy ? "Вход..." : "Войти"
                            color: "#fff"; font.pixelSize: 14; font.weight: Font.DemiBold
                        }
                    }
                    onClicked: doLogin()
                }
            }

            // ── REGISTER form ─────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; spacing: 10
                visible: root.tabIndex === 1

                Label { text: "Имя"; font.pixelSize: 12; font.weight: Font.DemiBold; color: textMuted }
                TextField {
                    id: regName
                    Layout.fillWidth: true; implicitHeight: 40
                    placeholderText: "Ваше имя"
                    onAccepted: regEmail.forceActiveFocus()
                }

                Label { text: "Email"; font.pixelSize: 12; font.weight: Font.DemiBold; color: textMuted }
                TextField {
                    id: regEmail
                    Layout.fillWidth: true; implicitHeight: 40
                    placeholderText: "you@example.com"
                    inputMethodHints: Qt.ImhEmailCharactersOnly
                    onAccepted: regPassword.forceActiveFocus()
                }

                Label { text: "Пароль"; font.pixelSize: 12; font.weight: Font.DemiBold; color: textMuted }
                TextField {
                    id: regPassword
                    Layout.fillWidth: true; implicitHeight: 40
                    placeholderText: "Минимум 6 символов"
                    echoMode: TextInput.Password
                }

                Item { height: 4 }

                // ── Role cards ────────────────────────────────────────────────
                Label { text: "Роль"; font.pixelSize: 12; font.weight: Font.DemiBold; color: textMuted }
                RowLayout {
                    Layout.fillWidth: true; spacing: 10

                    // Athlete card
                    Rectangle {
                        Layout.fillWidth: true; height: 78; radius: 12
                        color: root.selectedRole === "athlete" ? "#0d1f2d" : surface2
                        border.width: 2
                        border.color: root.selectedRole === "athlete" ? "#06b6d4" : borderCol
                        Behavior on border.color { ColorAnimation { duration: 140 } }
                        Behavior on color        { ColorAnimation { duration: 140 } }

                        Column {
                            anchors.centerIn: parent; spacing: 4
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "🏃"; font.pixelSize: 26
                            }
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Атлет"
                                font.pixelSize: 13; font.weight: Font.DemiBold
                                color: root.selectedRole === "athlete" ? "#06b6d4" : textMuted
                            }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedRole = "athlete"
                        }
                    }

                    // Coach card
                    Rectangle {
                        Layout.fillWidth: true; height: 78; radius: 12
                        color: root.selectedRole === "coach" ? "#1a2a1a" : surface2
                        border.width: 2
                        border.color: root.selectedRole === "coach" ? runColor : borderCol
                        Behavior on border.color { ColorAnimation { duration: 140 } }
                        Behavior on color        { ColorAnimation { duration: 140 } }

                        Column {
                            anchors.centerIn: parent; spacing: 4
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "🏋"; font.pixelSize: 26
                            }
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Тренер"
                                font.pixelSize: 13; font.weight: Font.DemiBold
                                color: root.selectedRole === "coach" ? runColor : textMuted
                            }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedRole = "coach"
                        }
                    }
                }

                Item { height: 4 }

                Label {
                    id: localHint
                    Layout.fillWidth: true
                    text: ""
                    visible: text.length > 0
                    color: "#fca5a5"; font.pixelSize: 12; wrapMode: Text.Wrap
                }

                Button {
                    Layout.fillWidth: true; implicitHeight: 42; highlighted: true
                    enabled: !workoutStore.busy
                    background: Rectangle {
                        radius: 10
                        color: parent.enabled ? (parent.hovered ? "#4f46e5" : accent) : "#2d2d50"
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    contentItem: RowLayout {
                        spacing: 8; anchors.centerIn: parent
                        BusyIndicator {
                            visible: workoutStore.busy; running: workoutStore.busy
                            implicitWidth: 18; implicitHeight: 18
                            palette.dark: "#fff"
                        }
                        Label {
                            text: workoutStore.busy ? "Создание..." : "Создать аккаунт"
                            color: "#fff"; font.pixelSize: 14; font.weight: Font.DemiBold
                        }
                    }
                    onClicked: doRegister()
                }
            }

            Item { height: 24 }
        }

        // ── Floating error toast (no longer pushes the form layout) ───────────
        Rectangle {
            id: errorToast
            anchors {
                left: parent.left; right: parent.right; bottom: parent.bottom
                leftMargin: 16; rightMargin: 16; bottomMargin: 16
            }
            visible: workoutStore.authError.length > 0
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
            height: errRow.implicitHeight + 14
            radius: 10
            color: "#2d1515"; border.width: 1; border.color: "#5a2020"
            z: 10

            RowLayout {
                id: errRow
                anchors { fill: parent; leftMargin: 12; rightMargin: 8; topMargin: 7; bottomMargin: 7 }
                spacing: 8
                Label { text: "⚠"; font.pixelSize: 14; color: "#ef4444" }
                Label {
                    Layout.fillWidth: true
                    text: workoutStore.authError; color: "#fca5a5"
                    font.pixelSize: 12; wrapMode: Text.Wrap
                    maximumLineCount: 3; elide: Text.ElideRight
                }
                RoundButton {
                    width: 24; height: 24; radius: 5; flat: true; text: "✕"; font.pixelSize: 11
                    onClicked: workoutStore.clearAuthError()
                }
            }
        }
    }

    // ── Action functions ──────────────────────────────────────────────────────
    function doLogin() {
        var email = loginEmail.text.trim()
        var pass  = loginPassword.text
        if (!email || !pass) {
            workoutStore.clearAuthError()
            return
        }
        workoutStore.loginUser(email, pass)
    }

    function doRegister() {
        var name  = regName.text.trim()
        var email = regEmail.text.trim()
        var pass  = regPassword.text
        var role  = root.selectedRole

        if (!name || !email) {
            workoutStore.clearAuthError()
            // set a local hint — reuse authError channel via a fake signal isn't possible,
            // so we rely on the button being visually disabled-like via the hint label
            localHint.text = "Заполните имя и email"
            return
        }
        if (pass.length < 6) {
            localHint.text = "Пароль — минимум 6 символов"
            return
        }
        if (!role) {
            localHint.text = "Выберите роль — Атлет или Тренер"
            return
        }
        localHint.text = ""
        workoutStore.registerUser(email, name, pass, role)
    }
}
