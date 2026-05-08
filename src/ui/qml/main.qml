import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "components"
import "."

ApplicationWindow {
    id: root
    visible: true
    width: 1440
    height: 880
    title: "PeMa"
    minimumWidth: 960
    minimumHeight: 640

    // ── Theme ──────────────────────────────────────────────────────────────
    property string themeMode: "light"
    property bool dark: themeMode === "dark" ||
                        (themeMode === "system" && Qt.styleHints.colorScheme === Qt.Dark)

    // Base palette
    property color bg:          dark ? "#0d1117" : "#f0f2f5"
    property color surface:     dark ? "#161b22" : "#ffffff"
    property color surface2:    dark ? "#21262d" : "#f6f8fa"
    property color border:      dark ? "#30363d" : "#dde3eb"
    property color textPrimary: dark ? "#e6edf3" : "#0d1117"
    property color textMuted:   dark ? "#8b949e" : "#57606a"

    // Sport accent palette
    property color accent:      "#6366f1"          // indigo — primary brand
    property color accentHover: dark ? "#818cf8" : "#4f46e5"
    property color energy:      "#f97316"          // orange — energy/power
    property color runColor:    "#22c55e"          // green  — run
    property color bikeColor:   "#f97316"          // orange — bike
    property color swimColor:   "#06b6d4"          // cyan   — swim
    property color easyColor:   "#22c55e"
    property color moderateColor:"#f59e0b"
    property color hardColor:   "#ef4444"
    property color todayBg:     dark ? "#1a2744" : "#dbeafe"
    property color selectedBg:  dark ? "#1f1a40" : "#ede9fe"

    color: bg
    font.family: Qt.platform.os === "osx" ? ".AppleSystemUIFont" : "Segoe UI"
    font.pixelSize: 13

    palette {
        window:          bg
        base:            surface
        alternateBase:   surface2
        windowText:      textPrimary
        text:            textPrimary
        button:          surface2
        buttonText:      textPrimary
        highlight:       accent
        highlightedText: "#ffffff"
        placeholderText: textMuted
    }

    // ── Draft state ────────────────────────────────────────────────────────
    property string draftTitle:    ""
    property string draftCategory: "run"
    property real   draftDistance: 5
    property int    draftDuration: 45
    property string draftIntensity:"moderate"
    property string draftNotes:    ""
    property bool   draftHidden:   false
    property string draftIntervals:"[]"
    property string editingWorkoutId: ""

    property string tplTitle:     ""
    property string tplCategory:  "run"
    property real   tplDistance:  10
    property int    tplDuration:  50
    property string tplIntensity: "moderate"
    property string tplTags:      ""
    property string tplNotes:     ""
    property string selectedTemplateId: ""
    property string planDateIso:  workoutStore.selectedDateIso
    property string feedbackDraft:""
    property string statusDraft:  "planned"
    property string moodDraft:    ""
    property int    perceivedExertionDraft: 0
    property string deleteWorkoutId: ""
    property string deleteTemplateId:""
    property var    selectedWorkoutObj: ({})
    property var    analyticsObj: ({})
    property var    painPointsMap: ({})
    property string analyticsPeriod: "all"     // 30d | 90d | year | all
    property string analyticsMetric: "distance" // distance | duration | count

    function painIdToName(id) {
        var m = {
            "head":"Голова","neck":"Шея",
            "lshoulder":"Лев. плечо","rshoulder":"Прав. плечо",
            "chest":"Грудь / пресс","lback":"Поясница",
            "lelbow":"Лев. локоть","relbow":"Прав. локоть",
            "lwrist":"Лев. запястье","rwrist":"Прав. запястье",
            "lhip":"Лев. бедро","rhip":"Прав. бедро",
            "lknee":"Лев. колено","rknee":"Прав. колено",
            "lshin":"Лев. голень","rshin":"Прав. голень",
            "lankle":"Лев. лодыжка","rankle":"Прав. лодыжка"
        }
        return m[id] || id
    }
    function parsePainFromFeedback(fb) {
        var map = {}
        var m = fb.match(/\[PainIds:([^\]]*)\]/)
        if (m && m[1]) {
            var ids = m[1].split(",")
            for (var i = 0; i < ids.length; i++) {
                var id = ids[i].trim()
                if (id) map[id] = true
            }
        }
        return map
    }
    function cleanFeedback(fb) {
        return fb.replace(/\s*\[PainIds:[^\]]*\]/, "").trim()
    }
    function buildFeedbackWithPain(fb) {
        var keys = []
        for (var k in root.painPointsMap) keys.push(k)
        if (keys.length === 0) return fb
        return fb.trim() + " [PainIds:" + keys.join(",") + "]"
    }
    function painMapKeys() {
        var keys = []
        for (var k in root.painPointsMap) keys.push(k)
        return keys
    }

    function catColor(c) {
        if (c === "run")  return runColor
        if (c === "bike") return bikeColor
        if (c === "swim") return swimColor
        return accent
    }
    function intColor(i) {
        if (i === "easy")     return easyColor
        if (i === "moderate") return moderateColor
        if (i === "hard")     return hardColor
        return textMuted
    }
    function catIcon(c) {
        if (c === "run")  return "🏃"
        if (c === "bike") return "🚴"
        if (c === "swim") return "🏊"
        return "⚡"
    }

    function resetDraft() {
        editingWorkoutId = ""
        draftTitle = ""; draftCategory = "run"; draftDistance = 5
        draftDuration = 45; draftIntensity = "moderate"
        draftNotes = ""; draftHidden = false; draftIntervals = "[]"
    }
    function fillDraftFromSelected() {
        const s = workoutStore.selectedWorkout
        if (!s || !s.id) return
        editingWorkoutId = s.id
        draftTitle    = s.title || ""
        draftCategory = s.category || "run"
        draftDistance = Number((s.distance || "0").replace(" км","")) || 0
        draftDuration = Number((s.duration || "0").replace(" мин","")) || 0
        draftIntensity= s.intensity || "moderate"
        draftNotes    = s.notes || ""
        draftHidden   = !!s.hidden
        draftIntervals= s.intervalsJson || "[]"
    }
    function statusIndex(v) {
        return v === "done" ? 1 : v === "skipped" ? 2 : 0
    }
    function moodLabel(v) {
        const m = { excellent:"Отлично", good:"Хорошо", normal:"Нормально", weak:"Слабость", awful:"Ужасно" }
        return m[v] || ""
    }
    function nextTheme() {
        if (themeMode === "light") themeMode = "dark"
        else if (themeMode === "dark") themeMode = "system"
        else themeMode = "light"
    }
    function themeIcon() {
        return themeMode === "dark" ? "☾" : themeMode === "system" ? "⊙" : "☼"
    }

    Connections {
        target: workoutStore
        function onWorkoutCreated()        { resetDraft() }
        function onSelectedDateChanged()   {
            planDateIso = workoutStore.selectedDateIso
            // Clear the selected workout so detail panel hides when switching days
            root.selectedWorkoutObj = ({})
            feedbackDraft = ""; statusDraft = "planned"; moodDraft = ""
            perceivedExertionDraft = 0; root.painPointsMap = ({})
        }
        function onSelectedWorkoutChanged(){
            root.selectedWorkoutObj = workoutStore.selectedWorkout
            const s = root.selectedWorkoutObj
            const rawFb = s?.athleteFeedback ?? ""
            feedbackDraft          = root.cleanFeedback(rawFb)
            statusDraft            = s?.status ?? "planned"
            moodDraft              = s?.athleteMood ?? ""
            perceivedExertionDraft = s?.perceivedExertion ?? 0
            root.painPointsMap     = root.parsePainFromFeedback(rawFb)
        }
        function onAnalyticsChanged()       { root.analyticsObj = workoutStore.analyticsSummary }
        function onAnalyticsPeriodChanged() { root.analyticsPeriod = workoutStore.analyticsPeriod }
        function onSessionExpired()         { sessionExpiredBanner.visible = true }
        function onLoggedOut()         { sessionExpiredBanner.visible = false }
    }
    Component.onCompleted: {
        root.selectedWorkoutObj = workoutStore.selectedWorkout
        root.analyticsObj       = workoutStore.analyticsSummary
    }

    // ── Error banner ───────────────────────────────────────────────────────
    ErrorBanner {
        id: errorBanner
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 8 }
        z: 100
        message: workoutStore.errorMessage
        onDismissed: workoutStore.clearError()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: errorBanner.visible ? 50 : 0
        spacing: 0

        // ── Top accent bar ──────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 3
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: runColor   }
                GradientStop { position: 0.4; color: accent     }
                GradientStop { position: 0.7; color: swimColor  }
                GradientStop { position: 1.0; color: bikeColor  }
            }
        }

        // ── Header ──────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 54
            color: surface
            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 1; color: border }

            RowLayout {
                anchors { fill: parent; leftMargin: 20; rightMargin: 16 }
                spacing: 6

                // Logo
                Row {
                    spacing: 6
                    Rectangle {
                        width: 28; height: 28; radius: 7
                        color: accent
                        anchors.verticalCenter: parent.verticalCenter
                        Label { anchors.centerIn: parent; text: "S"; font.pixelSize: 15; font.weight: Font.Black; color: "#fff" }
                    }
                    Label {
                        text: "PeMa"
                        font.pixelSize: 17
                        font.weight: Font.Bold
                        color: textPrimary
                        anchors.verticalCenter: parent.verticalCenter
                        font.letterSpacing: -0.3
                    }
                }

                // Nav tabs
                Row {
                    spacing: 2
                    Repeater {
                        model: ["Календарь", "Builder", "Аналитика", "Маршрут"]
                        delegate: Rectangle {
                            width: lbl.implicitWidth + 28
                            height: 34
                            radius: 8
                            color: mainTabs.currentIndex === index
                                   ? (dark ? "#1f1a40" : "#ede9fe")
                                   : "transparent"
                            // bottom accent line for active
                            Rectangle {
                                visible: mainTabs.currentIndex === index
                                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                height: 2; radius: 1
                                color: accent
                            }
                            Label {
                                id: lbl
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: 13
                                font.weight: mainTabs.currentIndex === index ? Font.DemiBold : Font.Normal
                                color: mainTabs.currentIndex === index ? accent : textMuted
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mainTabs.currentIndex = index
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Athlete selector (only coach sees multiple athletes)
                Label {
                    visible: workoutStore.currentUserRole === "coach" && workoutStore.athletes.length > 0
                    text: "Атлет"; color: textMuted; font.pixelSize: 12
                }
                ComboBox {
                    visible: workoutStore.currentUserRole === "coach" && workoutStore.athletes.length > 0
                    implicitWidth: 155; implicitHeight: 32
                    model: workoutStore.athletes
                    textRole: "name"; valueRole: "id"
                    onActivated: i => { const a = model[i]; if (a) workoutStore.selectedAthleteId = a.id }
                    Connections {
                        target: workoutStore
                        function onAthletesChanged() {
                            for (let i = 0; i < workoutStore.athletes.length; ++i)
                                if (workoutStore.athletes[i].id === workoutStore.selectedAthleteId) { currentIndex = i; break }
                        }
                    }
                }

                // "Add athlete" button for coaches
                RoundButton {
                    width: 32; height: 32; radius: 8; flat: true
                    text: "＋👤"; font.pixelSize: 12
                    visible: workoutStore.currentUserRole === "coach"
                    ToolTip.text: "Добавить атлета"; ToolTip.visible: hovered; ToolTip.delay: 500
                    onClicked: linkAthleteDialog.open()
                }

                // User pill
                Rectangle {
                    visible: workoutStore.isLoggedIn
                    height: 32; width: userPillRow.implicitWidth + 20; radius: 8
                    color: surface2; border.width: 1; border.color: border
                    RowLayout {
                        id: userPillRow
                        anchors.centerIn: parent; spacing: 6
                        Label {
                            text: workoutStore.currentUserRole === "coach" ? "🏋" : "🏃"
                            font.pixelSize: 14
                        }
                        Label {
                            text: workoutStore.currentUserName
                            font.pixelSize: 12; font.weight: Font.DemiBold
                            color: textPrimary
                        }
                    }
                }

                RoundButton {
                    width: 32; height: 32; radius: 8; flat: true
                    text: "⚙"; font.pixelSize: 16
                    onClicked: settingsPanel.toggle()
                    ToolTip.text: "Настройки"; ToolTip.visible: hovered; ToolTip.delay: 500
                }
                RoundButton {
                    width: 32; height: 32; radius: 8; flat: true
                    text: themeIcon(); font.pixelSize: 15
                    onClicked: nextTheme()
                    ToolTip.text: "Сменить тему"; ToolTip.visible: hovered; ToolTip.delay: 500
                }
                RoundButton {
                    visible: workoutStore.isLoggedIn
                    width: 32; height: 32; radius: 8; flat: true
                    text: "⏏"; font.pixelSize: 15
                    ToolTip.text: "Выйти"; ToolTip.visible: hovered; ToolTip.delay: 500
                    onClicked: workoutStore.logout()
                }
            }
        }

        // ── Calendar toolbar ────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: mainTabs.currentIndex === 0 ? 46 : 0
            visible: height > 0
            color: surface2
            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 1; color: border }
            RowLayout {
                anchors { fill: parent; leftMargin: 20; rightMargin: 20 }
                spacing: 8
                visible: mainTabs.currentIndex === 0
                Button { text: "Сегодня"; implicitHeight: 30; flat: true; onClicked: workoutStore.goToToday() }
                RoundButton { width: 30; height: 30; radius: 8; flat: true; text: "‹"; font.pixelSize: 18; onClicked: workoutStore.prevMonth() }
                Label {
                    text: workoutStore.monthLabel
                    font.pixelSize: 14; font.weight: Font.DemiBold
                    color: textPrimary
                    Layout.minimumWidth: 210; horizontalAlignment: Text.AlignHCenter
                }
                RoundButton { width: 30; height: 30; radius: 8; flat: true; text: "›"; font.pixelSize: 18; onClicked: workoutStore.nextMonth() }
                Item { Layout.fillWidth: true }
                // Sport role badge
                Rectangle {
                    height: 24; width: roleLbl.implicitWidth + 20; radius: 12
                    color: workoutStore.currentUserRole === "coach" ? (dark ? "#1a2f1a" : "#dcfce7") : (dark ? "#1a1a3a" : "#e0e7ff")
                    Label {
                        id: roleLbl
                        anchors.centerIn: parent
                        text: workoutStore.currentUserRole === "coach" ? "🏋 Тренер" : "🏃 Атлет"
                        font.pixelSize: 11; font.weight: Font.DemiBold
                        color: workoutStore.currentUserRole === "coach" ? runColor : accent
                    }
                }
                Button {
                    text: "+ Тренировка"
                    implicitHeight: 30
                    visible: workoutStore.canEditWorkouts
                    highlighted: true
                    background: Rectangle {
                        radius: 8
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: accent }
                            GradientStop { position: 1; color: "#818cf8" }
                        }
                    }
                    contentItem: Label {
                        text: parent.text; color: "#fff"
                        font.pixelSize: 13; font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: { resetDraft(); workoutStore.openCreateDialogForDate(workoutStore.selectedDateIso) }
                }
            }
        }

        // ── Content ─────────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            TabBar { id: mainTabs; visible: false }

            StackLayout {
                anchors.fill: parent
                currentIndex: mainTabs.currentIndex

                // ── TAB 0: Calendar ──────────────────────────────────────────
                RowLayout {
                    spacing: 0

                    // Grid
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        color: bg

                        ColumnLayout {
                            anchors { fill: parent; margins: 14 }
                            spacing: 6

                            // DOW header
                            RowLayout {
                                Layout.fillWidth: true; spacing: 4
                                Repeater {
                                    model: ["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС"]
                                    delegate: Label {
                                        Layout.fillWidth: true
                                        text: modelData
                                        horizontalAlignment: Text.AlignHCenter
                                        font.pixelSize: 10; font.weight: Font.Black
                                        font.letterSpacing: 1
                                        color: (index >= 5) ? hardColor : textMuted
                                    }
                                }
                            }

                            // Calendar grid
                            GridLayout {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                columns: 7; rowSpacing: 4; columnSpacing: 4

                                Repeater {
                                    model: workoutStore.dayCells
                                    delegate: Rectangle {
                                        Layout.fillWidth: true; Layout.fillHeight: true
                                        radius: 10
                                        property var day: modelData

                                        color: day.isSelected ? selectedBg
                                             : day.isToday    ? todayBg
                                             : day.inCurrentMonth ? surface : surface2

                                        border.width: day.isSelected ? 2 : day.isToday ? 1.5 : 1
                                        border.color: day.isSelected ? accent
                                                    : day.isToday    ? accentHover
                                                    : border

                                        MouseArea {
                                            id: hov; anchors.fill: parent
                                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: workoutStore.selectDate(day.dateIso)
                                        }

                                        // Add button
                                        Rectangle {
                                            anchors { top: parent.top; right: parent.right; margins: 4 }
                                            width: 18; height: 18; radius: 5; color: energy
                                            visible: hov.containsMouse && workoutStore.canEditWorkouts
                                            Label { anchors.centerIn: parent; text: "+"; font.pixelSize: 13; font.weight: Font.Bold; color: "#fff" }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: { resetDraft(); workoutStore.openCreateDialogForDate(day.dateIso) }
                                            }
                                        }

                                        // Goal marker 🎯 — overlaid in top-right when this date is a goal target
                                        Label {
                                            anchors { top: parent.top; right: parent.right; margins: 3 }
                                            text: "🎯"
                                            font.pixelSize: 10
                                            visible: {
                                                var iso = day.dateIso || ""
                                                var goals = workoutStore.goals
                                                for (var g = 0; g < goals.length; g++) {
                                                    if (goals[g].targetDate === iso) return true
                                                }
                                                return false
                                            }
                                            ToolTip.visible: {
                                                var iso = day.dateIso || ""
                                                var goals = workoutStore.goals
                                                for (var g = 0; g < goals.length; g++) {
                                                    if (goals[g].targetDate === iso) return hov.containsMouse
                                                }
                                                return false
                                            }
                                            ToolTip.text: {
                                                var iso = day.dateIso || ""
                                                var goals = workoutStore.goals
                                                var names = []
                                                for (var g = 0; g < goals.length; g++) {
                                                    if (goals[g].targetDate === iso) names.push(goals[g].title)
                                                }
                                                return names.join(", ")
                                            }
                                            ToolTip.delay: 200
                                        }

                                        Column {
                                            anchors { fill: parent; margins: 5 }
                                            spacing: 3

                                            Label {
                                                text: day.dayNumber
                                                font.pixelSize: 12; font.weight: day.isToday ? Font.Black : Font.Normal
                                                color: day.isToday    ? accentHover
                                                     : day.isSelected ? accent
                                                     : day.inCurrentMonth ? textPrimary : textMuted
                                            }

                                            Repeater {
                                                model: Math.min(day.workouts ? day.workouts.length : 0, 2)
                                                delegate: Rectangle {
                                                    property var wo: day.workouts[index]
                                                    width: parent.width; height: 22; radius: 5
                                                    color: Qt.rgba(
                                                        wo.category === "run"  ? 0.13 : wo.category === "bike" ? 0.98 : 0.02,
                                                        wo.category === "run"  ? 0.77 : wo.category === "bike" ? 0.45 : 0.71,
                                                        wo.category === "run"  ? 0.37 : wo.category === "bike" ? 0.09 : 0.83,
                                                        0.12
                                                    )
                                                    border.width: 1
                                                    border.color: Qt.rgba(
                                                        wo.category === "run"  ? 0.13 : wo.category === "bike" ? 0.98 : 0.02,
                                                        wo.category === "run"  ? 0.77 : wo.category === "bike" ? 0.45 : 0.71,
                                                        wo.category === "run"  ? 0.37 : wo.category === "bike" ? 0.09 : 0.83,
                                                        0.35
                                                    )
                                                    // Left sport color bar
                                                    Rectangle {
                                                        width: 3; height: parent.height - 4; radius: 3
                                                        anchors { left: parent.left; leftMargin: 0; verticalCenter: parent.verticalCenter }
                                                        color: wo.category === "run" ? runColor : wo.category === "bike" ? bikeColor : wo.category === "swim" ? swimColor : accent
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                        onClicked: { workoutStore.selectDate(day.dateIso); workoutStore.selectWorkout(wo.id) }
                                                    }
                                                    Label {
                                                        anchors { left: parent.left; leftMargin: 7; right: parent.right; rightMargin: 3; verticalCenter: parent.verticalCenter }
                                                        text: wo.typeIcon + " " + wo.title
                                                        font.pixelSize: 9; font.weight: Font.Medium
                                                        color: textPrimary; elide: Text.ElideRight
                                                    }
                                                }
                                            }
                                            // "+N more" badge
                                            Label {
                                                visible: day.workouts && day.workouts.length > 2
                                                text: "+" + (day.workouts ? day.workouts.length - 2 : 0) + " ещё"
                                                font.pixelSize: 9; color: textMuted
                                                leftPadding: 5
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Separator
                    Rectangle { width: 1; Layout.fillHeight: true; color: border }

                    // ── Detail panel ──────────────────────────────────────────
                    Rectangle {
                        Layout.preferredWidth: 310; Layout.fillHeight: true
                        color: surface

                        ScrollView {
                            anchors.fill: parent; contentWidth: availableWidth
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                            ColumnLayout {
                                width: parent.width; spacing: 0

                                // Date header
                                Rectangle {
                                    Layout.fillWidth: true; height: 58; color: "transparent"
                                    RowLayout {
                                        anchors { fill: parent; leftMargin: 14; rightMargin: 10; topMargin: 10; bottomMargin: 10 }
                                        ColumnLayout {
                                            Layout.fillWidth: true; spacing: 2
                                            Label { text: "ВЫБРАНА ДАТА"; font.pixelSize: 10; font.weight: Font.Black; color: textMuted; font.letterSpacing: 1.2 }
                                            Label { text: workoutStore.selectedDayLabel; font.pixelSize: 15; font.weight: Font.Bold; color: textPrimary }
                                        }
                                        // Add workout button
                                        Rectangle {
                                            width: 30; height: 30; radius: 8
                                            color: energy
                                            visible: workoutStore.canEditWorkouts
                                            Label { anchors.centerIn: parent; text: "+"; font.pixelSize: 18; font.weight: Font.Bold; color: "#fff" }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: { resetDraft(); workoutStore.openCreateDialogForDate(workoutStore.selectedDateIso) }
                                            }
                                        }
                                    }
                                }
                                Rectangle { Layout.fillWidth: true; height: 1; color: border }

                                // Day workouts
                                ColumnLayout {
                                    Layout.fillWidth: true; Layout.margins: 12; spacing: 6

                                    Label { text: "ТРЕНИРОВКИ"; font.pixelSize: 10; font.weight: Font.Black; color: textMuted; font.letterSpacing: 1.2; topPadding: 4 }

                                    Repeater {
                                        model: workoutStore.selectedDayWorkouts
                                        delegate: Rectangle {
                                            Layout.fillWidth: true; height: 56; radius: 10
                                            color: workoutStore.selectedWorkout.id === modelData.id
                                                   ? (dark ? "#1f1a40" : "#ede9fe") : surface2
                                            border.width: workoutStore.selectedWorkout.id === modelData.id ? 1.5 : 0
                                            border.color: accent

                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: workoutStore.selectWorkout(modelData.id) }

                                            Row {
                                                anchors { fill: parent; margins: 10 }
                                                spacing: 10
                                                // Category color pill
                                                Rectangle {
                                                    width: 4; height: parent.height; radius: 2
                                                    color: catColor(modelData.category)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                Column {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: parent.width - 14; spacing: 3
                                                    Label { width: parent.width; text: modelData.typeIcon + " " + modelData.title; font.pixelSize: 13; font.weight: Font.DemiBold; color: textPrimary; elide: Text.ElideRight }
                                                    Label { text: modelData.distance + " · " + modelData.duration + " · " + modelData.statusLabel; font.pixelSize: 11; color: textMuted }
                                                }
                                            }
                                        }
                                    }

                                    Label { visible: workoutStore.selectedDayWorkouts.length === 0; text: "Нет тренировок на этот день"; font.pixelSize: 12; color: textMuted; topPadding: 4 }
                                }

                                Rectangle { Layout.fillWidth: true; height: 1; color: border }

                                // Workout detail
                                ColumnLayout {
                                    Layout.fillWidth: true; Layout.margins: 12; spacing: 8
                                    visible: !!root.selectedWorkoutObj.id

                                    // Title row with category accent bar
                                    RowLayout {
                                        Layout.fillWidth: true; spacing: 10
                                        Rectangle { width: 3; height: 36; radius: 2; color: catColor(root.selectedWorkoutObj.category || "run") }
                                        ColumnLayout {
                                            Layout.fillWidth: true; spacing: 2
                                            Label {
                                                text: root.selectedWorkoutObj.title || ""
                                                font.pixelSize: 14; font.weight: Font.Black; color: textPrimary
                                                elide: Text.ElideRight; Layout.fillWidth: true
                                            }
                                            Label {
                                                text: (root.selectedWorkoutObj.category || "").toUpperCase() + "  ·  " + (root.selectedWorkoutObj.intensityLabel || "")
                                                font.pixelSize: 10; color: textMuted; font.letterSpacing: 0.5
                                            }
                                        }
                                    }

                                    // Stat table (план)
                                    Repeater {
                                        model: {
                                            var s = root.selectedWorkoutObj
                                            if (!s.id) return []
                                            return [
                                                { label: "Дистанция", value: s.distance || "—" },
                                                { label: "Длительность", value: s.duration || "—" },
                                                { label: "Статус", value: s.statusLabel || "—" },
                                            ]
                                        }
                                        delegate: RowLayout {
                                            Layout.fillWidth: true; spacing: 0
                                            Label { text: modelData.label; font.pixelSize: 12; color: textMuted; Layout.fillWidth: true }
                                            Label { text: modelData.value; font.pixelSize: 12; font.weight: Font.DemiBold; color: textPrimary }
                                        }
                                    }

                                    // Mood line
                                    RowLayout {
                                        Layout.fillWidth: true
                                        visible: !!root.selectedWorkoutObj.athleteMood
                                        Label { text: "Самочувствие"; font.pixelSize: 12; color: textMuted; Layout.fillWidth: true }
                                        Label { text: moodLabel(root.selectedWorkoutObj.athleteMood || ""); font.pixelSize: 12; font.weight: Font.DemiBold; color: textPrimary }
                                    }

                                    // Pain areas
                                    Label {
                                        Layout.fillWidth: true
                                        visible: /\[PainIds:/.test(root.selectedWorkoutObj.athleteFeedback || "")
                                        text: {
                                            var fb = root.selectedWorkoutObj.athleteFeedback || ""
                                            var m = fb.match(/\[PainIds:([^\]]*)\]/)
                                            if (!m || !m[1]) return ""
                                            var names = []
                                            var ids = m[1].split(",")
                                            for (var i = 0; i < ids.length; i++) {
                                                var id = ids[i].trim()
                                                if (id) names.push(root.painIdToName(id))
                                            }
                                            return "Болит: " + names.join(", ")
                                        }
                                        font.pixelSize: 11; color: hardColor; wrapMode: Text.Wrap
                                    }

                                    // Actual data (watch import) — table style
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 4
                                        visible: !!root.selectedWorkoutObj.actualDistanceKm

                                        Rectangle { Layout.fillWidth: true; height: 1; color: border }

                                        Label {
                                            text: "ФАКТ  ·  с часов"
                                            font.pixelSize: 9; font.weight: Font.Black; color: runColor; font.letterSpacing: 1.2
                                            topPadding: 4
                                        }

                                        Repeater {
                                            model: {
                                                var s = root.selectedWorkoutObj
                                                if (!s.id) return []
                                                var rows = []
                                                if (s.actualDistanceKm)    rows.push({ label: "Дистанция", value: Number(s.actualDistanceKm).toFixed(2) + " км" })
                                                if (s.actualDurationMin)   rows.push({ label: "Время", value: s.actualDurationMin + " мин" })
                                                if (s.actualAvgPace) {
                                                    var p = s.actualAvgPace
                                                    var pm = Math.floor(p); var ps = Math.round((p - pm) * 60)
                                                    rows.push({ label: "Темп", value: pm + ":" + (ps < 10 ? "0" : "") + ps + " /км" })
                                                }
                                                if (s.actualAvgHr)         rows.push({ label: "Пульс средн.", value: s.actualAvgHr + " уд/мин" })
                                                if (s.actualMaxHr)         rows.push({ label: "Пульс макс.", value: s.actualMaxHr + " уд/мин" })
                                                if (s.actualElevationGain) rows.push({ label: "Набор высоты", value: "+" + Math.round(s.actualElevationGain) + " м" })
                                                return rows
                                            }
                                            delegate: RowLayout {
                                                Layout.fillWidth: true
                                                Label { text: modelData.label; font.pixelSize: 11; color: textMuted; Layout.fillWidth: true }
                                                Label { text: modelData.value; font.pixelSize: 11; font.weight: Font.DemiBold; color: textPrimary }
                                            }
                                        }
                                    }

                                    // Action buttons
                                    RowLayout {
                                        Layout.fillWidth: true; spacing: 6
                                        visible: workoutStore.canEditWorkouts

                                        Rectangle {
                                            height: 30; width: editBtnLbl.implicitWidth + 20; radius: 7
                                            color: surface2; border.width: 1; border.color: border
                                            Label { id: editBtnLbl; anchors.centerIn: parent; text: "Изменить"; font.pixelSize: 12; color: textPrimary }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: { fillDraftFromSelected(); workoutStore.openCreateDialogForDate(root.selectedWorkoutObj.dateIso) } }
                                        }
                                        Rectangle {
                                            height: 30; width: delBtnLbl.implicitWidth + 20; radius: 7
                                            color: surface2; border.width: 1; border.color: border
                                            Label { id: delBtnLbl; anchors.centerIn: parent; text: "Удалить"; font.pixelSize: 12; color: hardColor }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: { deleteWorkoutId = root.selectedWorkoutObj.id; confirmDeleteWorkout.open() } }
                                        }
                                        Rectangle {
                                            height: 30; width: impBtnLbl.implicitWidth + 20; radius: 7
                                            color: surface2; border.width: 1; border.color: border
                                            Label { id: impBtnLbl; anchors.centerIn: parent; text: "Импорт"; font.pixelSize: 12; color: accent }
                                            ToolTip.text: "Импортировать данные с часов (.gpx/.fit)"
                                            ToolTip.visible: impMa.containsMouse; ToolTip.delay: 400
                                            MouseArea { id: impMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                                onClicked: { watchImportDialog.workoutId = root.selectedWorkoutObj.id; watchFileDialog.open() } }
                                        }
                                    }
                                }

                                Rectangle { Layout.fillWidth: true; height: 1; color: border; visible: !!root.selectedWorkoutObj.id }

                                // Status
                                ColumnLayout {
                                    Layout.fillWidth: true; Layout.margins: 12; spacing: 8
                                    visible: !!root.selectedWorkoutObj.id

                                    Label { text: "СТАТУС"; font.pixelSize: 10; font.weight: Font.Black; color: textMuted; font.letterSpacing: 1.2; topPadding: 4 }

                                    ComboBox {
                                        Layout.fillWidth: true; implicitHeight: 34
                                        model: [
                                            { label: "Запланировано", value: "planned" },
                                            { label: "Выполнено",     value: "done"    },
                                            { label: "Пропущено",     value: "skipped" }
                                        ]
                                        textRole: "label"; currentIndex: statusIndex(statusDraft)
                                        onActivated: i => {
                                            statusDraft = model[i].value
                                            if (statusDraft === "done" && perceivedExertionDraft === 0) perceivedExertionDraft = 1
                                        }
                                    }
                                    TextField { Layout.fillWidth: true; implicitHeight: 34; text: feedbackDraft; placeholderText: "Комментарий атлета..."; onTextChanged: feedbackDraft = text }

                                    // Mood
                                    ComboBox {
                                        Layout.fillWidth: true; implicitHeight: 34
                                        visible: statusDraft === "done"
                                        model: [
                                            { label:"😄 Отлично", value:"excellent" }, { label:"😊 Хорошо", value:"good" },
                                            { label:"😐 Нормально", value:"normal" }, { label:"😕 Слабость", value:"weak" },
                                            { label:"😞 Ужасно", value:"awful" }
                                        ]
                                        textRole: "label"
                                        currentIndex: { const a=["excellent","good","normal","weak","awful"]; return Math.max(0,a.indexOf(moodDraft)) }
                                        onActivated: i => { moodDraft = model[i].value }
                                    }

                                    // RPE
                                    ComboBox {
                                        Layout.fillWidth: true; implicitHeight: 34
                                        visible: statusDraft === "done"
                                        model: [
                                            { label:"RPE 1 — Очень легко",        value:1 },
                                            { label:"RPE 2 — Легко",              value:2 },
                                            { label:"RPE 3 — Умеренно",           value:3 },
                                            { label:"RPE 4 — Выше среднего",      value:4 },
                                            { label:"RPE 5 — Тяжело",             value:5 },
                                            { label:"RPE 6 — Очень тяжело",       value:6 },
                                        ]
                                        textRole: "label"
                                        currentIndex: Math.max(0, perceivedExertionDraft - 1)
                                        onActivated: i => { perceivedExertionDraft = model[i].value }
                                    }

                                    // ── Pain map ───────────────────────────────────
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 6
                                        visible: statusDraft === "done"

                                        Label {
                                            text: "БОЛЕВЫЕ ТОЧКИ"
                                            font.pixelSize: 10; font.weight: Font.Black
                                            color: textMuted; font.letterSpacing: 1.2
                                        }

                                        BodyPainMap {
                                            id: bodyMap
                                            activeIds: root.painPointsMap
                                            Layout.alignment: Qt.AlignHCenter
                                            silhouetteColor: dark ? "#475569" : "#cbd5e1"
                                            silhouetteEdge:  dark ? "#64748b" : "#94a3b8"
                                            onToggled: function(id, name) {
                                                var map = {}
                                                for (var k in root.painPointsMap) map[k] = root.painPointsMap[k]
                                                if (map[id]) delete map[id]
                                                else map[id] = true
                                                root.painPointsMap = map
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true; height: 34; radius: 8; color: accent
                                        Label { anchors.centerIn: parent; text: "Сохранить статус"; font.pixelSize: 13; font.weight: Font.DemiBold; color: "#fff" }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var fb = root.buildFeedbackWithPain(feedbackDraft)
                                                workoutStore.markWorkoutStatusDetailed(
                                                    root.selectedWorkoutObj.id, statusDraft,
                                                    fb, moodDraft, perceivedExertionDraft)
                                            }
                                        }
                                    }
                                }

                                Rectangle { Layout.fillWidth: true; height: 1; color: border; visible: !!root.selectedWorkoutObj.id }

                                // Comments
                                ColumnLayout {
                                    Layout.fillWidth: true; Layout.margins: 12; spacing: 8
                                    visible: !!root.selectedWorkoutObj.id

                                    Label { text: "КОММЕНТАРИИ"; font.pixelSize: 10; font.weight: Font.Black; color: textMuted; font.letterSpacing: 1.2; topPadding: 4 }

                                    Repeater {
                                        model: workoutStore.selectedWorkoutComments
                                        delegate: Rectangle {
                                            Layout.fillWidth: true
                                            height: cCol.implicitHeight + 16; radius: 8; color: surface2
                                            Column {
                                                id: cCol; anchors { fill: parent; margins: 10 }
                                                spacing: 3
                                                Label { text: modelData.author; font.pixelSize: 11; font.weight: Font.Bold; color: accent }
                                                Label { width: parent.width; text: modelData.text; font.pixelSize: 12; color: textPrimary; wrapMode: Text.Wrap }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true; spacing: 6
                                        TextField { id: cmtInput; Layout.fillWidth: true; implicitHeight: 34; placeholderText: "Комментарий..." }
                                        Button {
                                            text: "→"; implicitHeight: 34; implicitWidth: 34; highlighted: true
                                            onClicked: {
                                                workoutStore.addComment(cmtInput.text)
                                                cmtInput.text = ""
                                            }
                                        }
                                    }
                                }
                                Item { height: 16 }
                            }
                        }
                    }
                }

                // ── TAB 1: Builder ─────────────────────────────────────────────
                RowLayout {
                    spacing: 0

                    // ── Left: Form ───────────────────────────────────────────────
                    Rectangle {
                        Layout.preferredWidth: 300; Layout.fillHeight: true
                        color: surface

                        Rectangle {
                            anchors { top: parent.top; right: parent.right; bottom: parent.bottom }
                            width: 1; color: border
                        }

                        ScrollView {
                            anchors.fill: parent; contentWidth: availableWidth
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                            ColumnLayout {
                                width: parent.width; spacing: 0

                                // Header
                                Rectangle {
                                    Layout.fillWidth: true; height: 56; color: "transparent"
                                    RowLayout {
                                        anchors { fill: parent; leftMargin: 20; rightMargin: 16 }
                                        Label {
                                            text: selectedTemplateId ? "Редактировать" : "Новый шаблон"
                                            font.pixelSize: 17; font.weight: Font.Black; color: textPrimary; font.letterSpacing: -0.3
                                            Layout.fillWidth: true
                                        }
                                        Rectangle {
                                            width: resetLbl.implicitWidth + 16; height: 26; radius: 7
                                            color: surface2; border.width: 1; border.color: border
                                            Label { id: resetLbl; anchors.centerIn: parent; text: "Сброс"; font.pixelSize: 11; color: textMuted }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: { selectedTemplateId = ""; tplTitle = ""; tplCategory = "run"; tplDistance = 10; tplDuration = 50; tplIntensity = "moderate"; tplTags = ""; tplNotes = "" } }
                                        }
                                    }
                                }
                                Rectangle { Layout.fillWidth: true; height: 1; color: border }

                                ColumnLayout {
                                    Layout.fillWidth: true; Layout.margins: 20; spacing: 16

                                    // Название
                                    ColumnLayout { Layout.fillWidth: true; spacing: 6
                                        Label { text: "НАЗВАНИЕ"; font.pixelSize: 9; font.weight: Font.Black; color: textMuted; font.letterSpacing: 1.2 }
                                        TextField { Layout.fillWidth: true; implicitHeight: 36; text: tplTitle; placeholderText: "Название шаблона"; onTextChanged: tplTitle = text }
                                    }

                                    // Категория
                                    ColumnLayout { Layout.fillWidth: true; spacing: 6
                                        Label { text: "ВИД ТРЕНИРОВКИ"; font.pixelSize: 9; font.weight: Font.Black; color: textMuted; font.letterSpacing: 1.2 }
                                        ComboBox { Layout.fillWidth: true; implicitHeight: 36; model: workoutStore.categories; currentIndex: Math.max(0, model.indexOf(tplCategory)); onActivated: tplCategory = currentText }
                                    }

                                    // Объём
                                    ColumnLayout { Layout.fillWidth: true; spacing: 6
                                        Label { text: "ОБЪЁМ"; font.pixelSize: 9; font.weight: Font.Black; color: textMuted; font.letterSpacing: 1.2 }
                                        RowLayout { spacing: 10
                                            ColumnLayout { spacing: 3
                                                Label { text: "км"; font.pixelSize: 10; color: textMuted }
                                                SpinBox { implicitHeight: 36; implicitWidth: 100; from: 0; to: 500; value: Math.round(tplDistance); onValueModified: tplDistance = value }
                                            }
                                            ColumnLayout { spacing: 3
                                                Label { text: "мин"; font.pixelSize: 10; color: textMuted }
                                                SpinBox { implicitHeight: 36; implicitWidth: 100; from: 0; to: 600; value: tplDuration; onValueModified: tplDuration = value }
                                            }
                                        }
                                    }

                                    // Интенсивность
                                    ColumnLayout { Layout.fillWidth: true; spacing: 6
                                        Label { text: "ИНТЕНСИВНОСТЬ"; font.pixelSize: 9; font.weight: Font.Black; color: textMuted; font.letterSpacing: 1.2 }
                                        ComboBox { Layout.fillWidth: true; implicitHeight: 36; model: workoutStore.intensities; currentIndex: Math.max(0, model.indexOf(tplIntensity)); onActivated: tplIntensity = currentText }
                                    }

                                    // Теги
                                    ColumnLayout { Layout.fillWidth: true; spacing: 6
                                        Label { text: "ТЕГИ"; font.pixelSize: 9; font.weight: Font.Black; color: textMuted; font.letterSpacing: 1.2 }
                                        TextField { Layout.fillWidth: true; implicitHeight: 36; text: tplTags; placeholderText: "через запятую"; onTextChanged: tplTags = text }
                                    }

                                    // Заметки
                                    ColumnLayout { Layout.fillWidth: true; spacing: 6
                                        Label { text: "ЗАМЕТКИ"; font.pixelSize: 9; font.weight: Font.Black; color: textMuted; font.letterSpacing: 1.2 }
                                        TextArea {
                                            Layout.fillWidth: true; implicitHeight: 80
                                            text: tplNotes; placeholderText: "Описание тренировки"
                                            onTextChanged: tplNotes = text
                                            background: Rectangle { radius: 8; color: surface2; border.width: 1; border.color: border }
                                        }
                                    }

                                    // Save button
                                    Rectangle {
                                        Layout.fillWidth: true; height: 36; radius: 8
                                        color: workoutStore.canEditWorkouts ? accent : border
                                        opacity: workoutStore.canEditWorkouts ? 1.0 : 0.5
                                        Label { anchors.centerIn: parent; text: selectedTemplateId ? "Сохранить шаблон" : "Создать шаблон"; font.pixelSize: 13; font.weight: Font.DemiBold; color: "#fff" }
                                        MouseArea { anchors.fill: parent; enabled: workoutStore.canEditWorkouts; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (selectedTemplateId) workoutStore.updateTemplate(selectedTemplateId, tplTitle, tplCategory, tplDistance, tplDuration, tplIntensity, "", tplNotes, tplTags)
                                                else workoutStore.saveTemplate(tplTitle, tplCategory, tplDistance, tplDuration, tplIntensity, "", tplNotes, tplTags)
                                            }
                                        }
                                    }
                                    Item { height: 4 }
                                }
                            }
                        }
                    }

                    // ── Right: Library ───────────────────────────────────────────
                    Item {
                        Layout.fillWidth: true; Layout.fillHeight: true

                        ColumnLayout {
                            anchors { fill: parent; margins: 0 }
                            spacing: 0

                            // Library header
                            Rectangle {
                                Layout.fillWidth: true; height: 56; color: "transparent"
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 20; rightMargin: 20 }
                                    Label {
                                        text: "Библиотека"
                                        font.pixelSize: 17; font.weight: Font.Black; color: textPrimary; font.letterSpacing: -0.3
                                        Layout.fillWidth: true
                                    }
                                    Label { text: "Дата"; font.pixelSize: 12; color: textMuted }
                                    TextField {
                                        implicitWidth: 110; implicitHeight: 30; text: planDateIso
                                        placeholderText: "ГГГГ-ММ-ДД"; font.pixelSize: 12
                                        onTextChanged: planDateIso = text
                                    }
                                }
                            }
                            Rectangle { Layout.fillWidth: true; height: 1; color: border }

                            // Template list
                            ListView {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                model: workoutStore.templateLibrary; spacing: 0; clip: true

                                delegate: Rectangle {
                                    width: ListView.view.width; height: 72
                                    color: selectedTemplateId === modelData.id ? (dark ? "#16123a" : "#f5f3ff") : "transparent"
                                    border.width: 0

                                    // bottom separator
                                    Rectangle {
                                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 20; rightMargin: 20 }
                                        height: 1; color: border; opacity: 0.7
                                    }

                                    RowLayout {
                                        anchors { fill: parent; leftMargin: 20; rightMargin: 16 }
                                        spacing: 12

                                        Rectangle { width: 3; height: 40; radius: 2; color: catColor(modelData.category) }

                                        ColumnLayout {
                                            Layout.fillWidth: true; spacing: 3
                                            Label { text: modelData.title; font.pixelSize: 13; font.weight: Font.DemiBold; color: textPrimary; elide: Text.ElideRight; Layout.fillWidth: true }
                                            Label {
                                                text: modelData.distanceKm + " км  ·  " + modelData.durationMin + " мин  ·  " + modelData.intensity
                                                font.pixelSize: 11; color: textMuted
                                            }
                                        }

                                        // Buttons
                                        RowLayout { spacing: 6
                                            Rectangle {
                                                height: 28; width: toPlanLbl.implicitWidth + 16; radius: 7
                                                color: accent
                                                visible: workoutStore.canEditWorkouts && /^\d{4}-\d{2}-\d{2}$/.test(planDateIso)
                                                Label { id: toPlanLbl; anchors.centerIn: parent; text: "В план"; font.pixelSize: 11; font.weight: Font.DemiBold; color: "#fff" }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                    onClicked: workoutStore.planFromTemplate(modelData.id, planDateIso) }
                                            }
                                            Rectangle {
                                                height: 28; width: 28; radius: 7
                                                color: surface2; border.width: 1; border.color: border
                                                visible: workoutStore.canEditWorkouts
                                                Label { anchors.centerIn: parent; text: "✎"; font.pixelSize: 13; color: textMuted }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                    onClicked: { selectedTemplateId = modelData.id; tplTitle = modelData.title; tplCategory = modelData.category; tplDistance = modelData.distanceKm; tplDuration = modelData.durationMin; tplIntensity = modelData.intensity; tplNotes = modelData.notes; tplTags = modelData.tags } }
                                            }
                                            Rectangle {
                                                height: 28; width: 28; radius: 7
                                                color: surface2; border.width: 1; border.color: border
                                                visible: workoutStore.canEditWorkouts
                                                Label { anchors.centerIn: parent; text: "×"; font.pixelSize: 15; color: textMuted }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                    onClicked: { deleteTemplateId = modelData.id; confirmDeleteTemplate.open() } }
                                            }
                                        }
                                    }

                                    MouseArea { anchors.fill: parent; z: -1; cursorShape: Qt.PointingHandCursor
                                        onClicked: selectedTemplateId = (selectedTemplateId === modelData.id ? "" : modelData.id) }
                                }

                                // Empty state
                                Label {
                                    anchors.centerIn: parent
                                    visible: workoutStore.templateLibrary.length === 0
                                    text: "Шаблонов пока нет"
                                    font.pixelSize: 13; color: textMuted
                                }
                            }
                        }
                    }
                }

                // ── TAB 2: Analytics — minimalist redesign ─────────────────
                Item {
                    // Two-column layout: stats left, charts right
                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        // ── Left column: numbers + goals ─────────────────────────
                        Rectangle {
                            Layout.preferredWidth: 320; Layout.fillHeight: true
                            color: surface
                            Rectangle {
                                anchors { top: parent.top; right: parent.right; bottom: parent.bottom }
                                width: 1; color: border
                            }

                            ScrollView {
                                anchors.fill: parent; contentWidth: availableWidth
                                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                                ColumnLayout {
                                    width: parent.width; spacing: 0

                                    // Header + period
                                    Rectangle {
                                        Layout.fillWidth: true; height: 58; color: "transparent"
                                        RowLayout {
                                            anchors { fill: parent; leftMargin: 20; rightMargin: 16; topMargin: 12; bottomMargin: 8 }
                                            ColumnLayout {
                                                spacing: 1; Layout.fillWidth: true
                                                Label { text: "Аналитика"; font.pixelSize: 16; font.weight: Font.Black; color: textPrimary; font.letterSpacing: -0.3 }
                                                Label { text: workoutStore.selectedAthleteName; font.pixelSize: 11; color: textMuted }
                                            }
                                        }
                                    }

                                    // Period buttons row
                                    Rectangle {
                                        Layout.fillWidth: true; height: 40; color: "transparent"
                                        Row {
                                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 20; rightMargin: 16 }
                                            spacing: 6
                                            Repeater {
                                                model: [{ l:"30д",v:"30d"},{ l:"90д",v:"90d"},{ l:"Год",v:"year"},{ l:"Всё",v:"all"}]
                                                Rectangle {
                                                    width: periodLbl.implicitWidth + 14; height: 26; radius: 6
                                                    color: workoutStore.analyticsPeriod === modelData.v ? accent : "transparent"
                                                    Label { id: periodLbl; anchors.centerIn: parent; text: modelData.l; font.pixelSize: 11; font.weight: Font.DemiBold
                                                            color: workoutStore.analyticsPeriod === modelData.v ? "#fff" : textMuted }
                                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: workoutStore.analyticsPeriod = modelData.v }
                                                }
                                            }
                                        }
                                    }

                                    Rectangle { Layout.fillWidth: true; height: 1; color: border }

                                    // ── Key numbers (clean table style) ──────────
                                    ColumnLayout {
                                        Layout.fillWidth: true; Layout.leftMargin: 20; Layout.rightMargin: 20; Layout.topMargin: 16; spacing: 0

                                        Repeater {
                                            model: [
                                                { label: "Тренировок выполнено", value: String(root.analyticsObj.workoutsCount || 0), sub: "" },
                                                { label: "Километров", value: Number(root.analyticsObj.distanceTotal || 0).toFixed(1), sub: "" },
                                                { label: "Минут", value: String(root.analyticsObj.durationTotal || 0), sub: "" },
                                                { label: "Выполнение плана", value: Math.round((root.analyticsObj.completionRate || 0) * 100) + "%", sub: "" },
                                                { label: "Серия подряд", value: String(root.analyticsObj.currentStreak || 0) + " дн.", sub: "рекорд " + (root.analyticsObj.longestStreak || 0) + " дн." },
                                                { label: "Средний темп", value: root.analyticsObj.avgPaceMinPerKm ?
                                                    (function(){ var p=root.analyticsObj.avgPaceMinPerKm||0; var m=Math.floor(p); var s=Math.round((p-m)*60); return m+":"+(s<10?"0":"")+s+" /км" })()
                                                    : "—", sub: root.analyticsObj.avgHrBpm ? (root.analyticsObj.avgHrBpm + " уд/мин") : "" },
                                            ]
                                            delegate: Rectangle {
                                                Layout.fillWidth: true; height: 50
                                                color: "transparent"
                                                // Bottom separator
                                                Rectangle {
                                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                                    height: 1; color: border; opacity: 0.6
                                                }
                                                RowLayout {
                                                    anchors { fill: parent; topMargin: 8; bottomMargin: 8 }
                                                    ColumnLayout {
                                                        Layout.fillWidth: true; spacing: 2
                                                        Label { text: modelData.label; font.pixelSize: 12; color: textMuted }
                                                        Label { text: modelData.sub; font.pixelSize: 10; color: textMuted; visible: modelData.sub !== "" }
                                                    }
                                                    Label {
                                                        text: modelData.value
                                                        font.pixelSize: 20; font.weight: Font.Black; color: textPrimary; font.letterSpacing: -0.5
                                                        Layout.preferredWidth: 90
                                                        horizontalAlignment: Text.AlignRight
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Item { height: 16 }
                                    Rectangle { Layout.fillWidth: true; height: 1; color: border }

                                    // ── Intensity bars ────────────────────────────
                                    ColumnLayout {
                                        Layout.fillWidth: true; Layout.leftMargin: 20; Layout.rightMargin: 20; Layout.topMargin: 14; spacing: 12

                                        Label { text: "Интенсивность"; font.pixelSize: 11; font.weight: Font.Black; color: textMuted; font.letterSpacing: 0.8 }

                                        Repeater {
                                            model: [
                                                { label: "Легко",    key: "easy"     },
                                                { label: "Умеренно", key: "moderate" },
                                                { label: "Тяжело",   key: "hard"     },
                                            ]
                                            delegate: ColumnLayout {
                                                Layout.fillWidth: true; spacing: 4
                                                property int val: (root.analyticsObj.byIntensity && root.analyticsObj.byIntensity[modelData.key]) || 0
                                                property int total: Math.max(1, root.analyticsObj.workoutsCount || 1)
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    Label { text: modelData.label; font.pixelSize: 12; color: textPrimary; Layout.fillWidth: true }
                                                    Label { text: String(val); font.pixelSize: 12; font.weight: Font.Bold; color: textPrimary }
                                                }
                                                Rectangle {
                                                    Layout.fillWidth: true; height: 4; radius: 2
                                                    color: dark ? "#30363d" : "#e2e8f0"
                                                    Rectangle {
                                                        width: parent.width * (val / total); height: parent.height; radius: 2
                                                        color: accent
                                                        Behavior on width { NumberAnimation { duration: 500 } }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Item { height: 16 }
                                    Rectangle { Layout.fillWidth: true; height: 1; color: border }

                                    // ── Goals ─────────────────────────────────────
                                    ColumnLayout {
                                        Layout.fillWidth: true; Layout.leftMargin: 20; Layout.rightMargin: 20; Layout.topMargin: 14; spacing: 10

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Label { text: "Цели"; font.pixelSize: 11; font.weight: Font.Black; color: textMuted; font.letterSpacing: 0.8 }
                                            Item { Layout.fillWidth: true }
                                            Label {
                                                text: "＋ добавить"
                                                font.pixelSize: 11; color: accent; font.weight: Font.DemiBold
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: goalCreateDialog.open() }
                                            }
                                        }

                                        GoalsList {
                                            Layout.fillWidth: true
                                            surface: root.surface; surface2: root.surface2
                                            borderCol: root.border; textPrimary: root.textPrimary
                                            textMuted: root.textMuted; accent: root.accent
                                            runColor: root.runColor; hardColor: root.hardColor; dark: root.dark
                                            goalsModel: root.analyticsObj.activeGoals || workoutStore.goals
                                            onDeleteRequested: function(id) { workoutStore.deleteGoal(id) }
                                            onAddRequested: goalCreateDialog.open()
                                        }
                                    }

                                    // ── Coach section ─────────────────────────────
                                    ColumnLayout {
                                        visible: workoutStore.currentUserRole === "coach"
                                        Layout.fillWidth: true; Layout.leftMargin: 20; Layout.rightMargin: 20; Layout.topMargin: 8; spacing: 6

                                        Rectangle { Layout.fillWidth: true; height: 1; color: border }

                                        Label { text: "Тренерский workspace"; font.pixelSize: 11; font.weight: Font.Black; color: textMuted; font.letterSpacing: 0.8; topPadding: 8 }
                                        Label { text: "Атлет: " + (workoutStore.selectedAthleteName || "не выбран"); font.pixelSize: 12; color: textPrimary }
                                        Label {
                                            text: workoutStore.athletes.length > 0
                                                  ? (workoutStore.athletes.length + " атлет(а) связано")
                                                  : "Нажмите ＋👤 в шапке чтобы добавить атлета"
                                            font.pixelSize: 11; color: textMuted; wrapMode: Text.Wrap; Layout.fillWidth: true
                                        }
                                    }

                                    Item { height: 24 }
                                }
                            }
                        }

                        // ── Right column: charts ──────────────────────────────────
                        Rectangle {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            color: bg

                            ScrollView {
                                anchors.fill: parent; contentWidth: availableWidth
                                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                                ColumnLayout {
                                    width: parent.width; spacing: 16
                                    anchors { leftMargin: 20; rightMargin: 20; topMargin: 20 }

                                    // Metric toggle (km / min / count)
                                    Rectangle {
                                        Layout.fillWidth: true; Layout.leftMargin: 20; Layout.rightMargin: 20
                                        height: 34; radius: 8; color: surface; border.width: 1; border.color: border
                                        RowLayout {
                                            anchors { fill: parent; margins: 4 }
                                            spacing: 2
                                            Repeater {
                                                model: [{ l:"км", v:"distance"},{l:"мин",v:"duration"},{l:"трен.",v:"count"}]
                                                Rectangle {
                                                    Layout.fillWidth: true; height: parent.height; radius: 6
                                                    color: root.analyticsMetric === modelData.v ? (dark ? "#30363d" : "#f1f5f9") : "transparent"
                                                    Label { anchors.centerIn: parent; text: modelData.l; font.pixelSize: 12; font.weight: Font.DemiBold
                                                            color: root.analyticsMetric === modelData.v ? textPrimary : textMuted }
                                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.analyticsMetric = modelData.v }
                                                }
                                            }
                                        }
                                    }

                                    // Charts (from AnalyticsCharts.qml — monochrome accent-only)
                                    AnalyticsCharts {
                                        Layout.fillWidth: true; Layout.leftMargin: 20; Layout.rightMargin: 20
                                        surface: root.surface; surface2: root.surface2; borderCol: root.border
                                        textPrimary: root.textPrimary; textMuted: root.textMuted
                                        accent: root.accent; runColor: root.accent  // use single accent color for both chart types
                                        dark: root.dark
                                        weeklyVolume:  root.analyticsObj.weeklyVolume  || []
                                        monthlyVolume: root.analyticsObj.monthlyVolume || []
                                        metric: root.analyticsMetric
                                    }

                                    Item { height: 8 }
                                }
                            }
                        }
                    }
                }

                // ── TAB 3: Маршрут ────────────────────────────────────────────
                RouteTab {
                    bg:          root.bg
                    surface:     root.surface
                    surface2:    root.surface2
                    borderCol:   root.border
                    textPrimary: root.textPrimary
                    textMuted:   root.textMuted
                    accent:      root.accent
                    runColor:    root.runColor
                    dark:        root.dark

                    routesModel:        workoutStore.routes
                    isBusy:             workoutStore.busy
                    stravaConnected:    workoutStore.stravaConnected
                    stravaHasClientId:  workoutStore.stravaHasClientId

                    onGenerateRequested: function(lat, lon, distKm, prefs) {
                        workoutStore.generateRoute(lat, lon, distKm, prefs)
                    }
                    onDeleteRouteRequested: function(id) {
                        workoutStore.deleteRoute(id)
                    }
                    onBuildFromWaypointsRequested: function(waypoints, name) {
                        workoutStore.buildRouteFromWaypoints(waypoints, name)
                    }
                    onConnectStravaRequested: {
                        workoutStore.openStravaAuthUrl()
                    }
                    onDisconnectStravaRequested: {
                        workoutStore.disconnectStrava()
                    }
                    onSyncStravaRequested: {
                        workoutStore.syncStrava()
                    }
                    onOpenStravaSettingsRequested: {
                        stravaSettingsDlg.open()
                    }
                }
            }
        }
    }

    // ── Watch import file dialog ─────────────────────────────────────────────
    QtObject {
        id: watchImportDialog
        property string workoutId: ""
    }

    FileDialog {
        id: watchFileDialog
        title: "Выберите файл с часов"
        nameFilters: ["GPS/Activity files (*.gpx *.fit)", "GPX files (*.gpx)", "FIT files (*.fit)", "All files (*)"]
        onAccepted: {
            if (watchImportDialog.workoutId) {
                var path = selectedFile.toString().replace("file://", "")
                workoutStore.importWatchFile(watchImportDialog.workoutId, path)
            }
        }
    }

    // ── OpenAI key dialog ────────────────────────────────────────────────────
    OpenAiKeyDialog {
        id: openAiKeyDlg
        textMuted:   root.textMuted
        accent:      root.accent
        surface2:    root.surface2
        borderCol:   root.border
        hasKey:      workoutStore.hasOpenAiKey
        onKeySet: function(key) { workoutStore.setOpenAiKey(key) }
    }

    // ── Goal creation dialog ─────────────────────────────────────────────────
    GoalDialog {
        id: goalCreateDialog
        surface:     root.surface
        surface2:    root.surface2
        borderCol:   root.border
        textPrimary: root.textPrimary
        textMuted:   root.textMuted
        accent:      root.accent
        onGoalCreated: function(title, targetDate, type, targetValue, targetUnit) {
            workoutStore.createGoal(title, targetDate, type, targetValue, targetUnit)
        }
    }

    // ── Strava settings dialog ───────────────────────────────────────────────
    Dialog {
        id: stravaSettingsDlg
        title: "Настройки Strava"
        anchors.centerIn: Overlay.overlay
        width: 360
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel

        property string savedClientId: ""
        property string savedClientSecret: ""

        onOpened: {
            stravaClientIdField.text    = ""
            stravaClientSecretField.text = ""
        }
        onAccepted: {
            var cid = stravaClientIdField.text.trim()
            var cs  = stravaClientSecretField.text.trim()
            if (cid && cs)
                workoutStore.saveStravaCredentials(cid, cs)
        }

        ColumnLayout {
            width: parent.width; spacing: 14
            Label {
                Layout.fillWidth: true; wrapMode: Text.Wrap
                text: "Создайте приложение на strava.com/settings/api, скопируйте Client ID и Client Secret."
                font.pixelSize: 12; color: root.textMuted
            }
            Label { text: "Client ID"; font.pixelSize: 11; font.weight: Font.DemiBold; color: root.textPrimary }
            TextField {
                id: stravaClientIdField
                Layout.fillWidth: true; placeholderText: "12345"
                font.pixelSize: 13
            }
            Label { text: "Client Secret"; font.pixelSize: 11; font.weight: Font.DemiBold; color: root.textPrimary }
            TextField {
                id: stravaClientSecretField
                Layout.fillWidth: true; placeholderText: "abc123..."
                font.pixelSize: 13; echoMode: TextInput.PasswordEchoOnEdit
            }
            Label {
                Layout.fillWidth: true; wrapMode: Text.Wrap
                text: "После сохранения нажмите «Подключить Strava» — откроется браузер для авторизации."
                font.pixelSize: 11; color: root.textMuted
            }
        }
    }

    // ── Dialogs ─────────────────────────────────────────────────────────────
    CreateWorkoutPopup {
        id: createDialog; visible: workoutStore.createDialogOpen
        dialogTitle:     editingWorkoutId ? "Редактировать тренировку" : "Новая тренировка"
        draftDateIso:    workoutStore.draftDateIso
        workoutTitle:    draftTitle;    workoutCategory:  draftCategory
        workoutDistance: draftDistance; workoutDuration:  draftDuration
        workoutIntensity:draftIntensity; workoutNotes:    draftNotes
        workoutHidden:   draftHidden
        hasDistance:     draftDistance > 0
        hasDuration:     draftDuration > 0
        categories:      workoutStore.categories; intensities: workoutStore.intensities
        busy:            workoutStore.busy
        saveEnabled:     workoutStore.canEditWorkouts
        saveDisabledHint:workoutStore.canEditWorkouts ? "" : "Только тренер может создавать тренировки."
        onCancelRequested: workoutStore.cancelCreateDialog()
        onSaveRequested: (title, cat, dist, dur, intens, notes, hidden) => {
            if (editingWorkoutId) workoutStore.updateWorkout(editingWorkoutId, title, cat, dist, dur, intens, notes, hidden, "[]")
            else workoutStore.createWorkout(title, cat, dist, dur, intens, notes, hidden, "[]")
        }
    }

    Dialog {
        id: confirmDeleteWorkout; title: "Удалить тренировку?"; modal: true
        anchors.centerIn: Overlay.overlay; standardButtons: Dialog.Yes | Dialog.Cancel
        Label { text: "Это действие нельзя отменить." }
        onAccepted: { workoutStore.deleteWorkout(deleteWorkoutId); deleteWorkoutId = "" }
        onRejected: deleteWorkoutId = ""
    }
    Dialog {
        id: confirmDeleteTemplate; title: "Удалить шаблон?"; modal: true
        anchors.centerIn: Overlay.overlay; standardButtons: Dialog.Yes | Dialog.Cancel
        Label { text: "Это действие нельзя отменить." }
        onAccepted: { workoutStore.deleteTemplate(deleteTemplateId); deleteTemplateId = "" }
        onRejected: deleteTemplateId = ""
    }

    // ── Link-athlete dialog (coach only) ─────────────────────────────────────
    Dialog {
        id: linkAthleteDialog
        title: "Добавить атлета"
        modal: true
        anchors.centerIn: Overlay.overlay
        standardButtons: Dialog.Ok | Dialog.Cancel

        property string athleteEmail: ""

        onOpened: { athleteEmail = ""; linkEmailField.text = "" }
        onAccepted: {
            var email = linkEmailField.text.trim()
            if (email.length > 0) workoutStore.linkAthlete(email)
        }

        ColumnLayout {
            spacing: 10; width: 300
            Label { text: "Email атлета:"; font.pixelSize: 12; color: root.textMuted }
            TextField {
                id: linkEmailField
                Layout.fillWidth: true; implicitHeight: 38
                placeholderText: "athlete@example.com"
                inputMethodHints: Qt.ImhEmailCharactersOnly
            }
        }
    }

    // ── Session-expired notification banner ───────────────────────────────────
    Rectangle {
        id: sessionExpiredBanner
        visible: false
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 44; z: 200
        color: "#7c2d12"
        RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 12 }
            spacing: 10
            Label { text: "⚠  Сессия истекла — пожалуйста, войдите снова."; color: "#fef3c7"; font.pixelSize: 13; Layout.fillWidth: true }
            RoundButton { width: 28; height: 28; radius: 6; flat: true; text: "✕"; font.pixelSize: 12; onClicked: sessionExpiredBanner.visible = false }
        }
    }

    // ── Settings panel ───────────────────────────────────────────────────────
    SettingsPanel {
        id: settingsPanel
        anchors.fill: parent
        z: 250

        bg:          root.bg
        surface:     root.surface
        surface2:    root.surface2
        borderCol:   root.border
        textPrimary: root.textPrimary
        textMuted:   root.textMuted
        accent:      root.accent
        dark:        root.dark

        themeMode:    root.themeMode
        serverUrl:    workoutStore.serverUrl
        hasOpenAiKey: workoutStore.hasOpenAiKey

        onThemeModeChangeRequested: function(mode) { root.themeMode = mode }
        onServerUrlChangeRequested: function(url) { workoutStore.serverUrl = url }
        onOpenAiKeyRequested: {
            settingsPanel.close()
            openAiKeyDlg.open()
        }
    }

    // ── Auth overlay ──────────────────────────────────────────────────────────
    AuthScreen {
        anchors.fill: parent
        z: 300
        visible: !workoutStore.isLoggedIn

        // Forward theme colours from the window so the card adapts
        bg:          root.bg
        surface:     root.surface
        surface2:    root.surface2
        borderCol:   root.border
        textPrimary: root.textPrimary
        textMuted:   root.textMuted
        accent:      root.accent
        runColor:    root.runColor
    }
}
