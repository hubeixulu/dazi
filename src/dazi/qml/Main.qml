import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    width: 1180
    height: 760
    minimumWidth: 920
    minimumHeight: 620
    visible: true
    title: "打字星球"
    color: "#F6F5FB"

    property int page: 0
    property var activeLesson: ({})
    property var practiceResult: ({})
    property bool practiceDone: false
    property int practiceGeneration: 0
    property var practiceParts: []
    property var practiceTexts: []
    property string courseDifficulty: "normal"
    property string courseType: "全部"
    property string searchQuery: ""
    property string importDifficulty: "normal"
    property string importPath: ""
    property string importFilename: ""
    property var pendingDeleteLesson: ({})
    property string noticeText: ""
    property bool noticeSuccess: true
    property int accent: 0
    readonly property var colors: ["#6657E8", "#27B99A", "#FF9C55", "#EF6C93"]

    function splitPracticeText(text, language) {
        var size = language === "zh" ? 32 : 68
        var parts = []
        var start = 0
        while (start < text.length) {
            var end = Math.min(start + size, text.length)
            if (language === "zh" && end < text.length) {
                var minimum = start + Math.floor(size * 0.55)
                for (var i = end - 1; i >= minimum; --i) {
                    if ("。！？；".indexOf(text.charAt(i)) >= 0) {
                        end = i + 1
                        break
                    }
                }
            }
            parts.push(text.slice(start, end))
            start = end
        }
        return parts
    }

    function focusPracticeIndex(index, initialText) {
        if (index < 0 || index >= practiceParts.length)
            return
        var rowsPerPage = Math.max(1, Math.floor(practiceList.height / 114))
        var startsPage = index % rowsPerPage === 0
        practiceList.positionViewAtIndex(index, startsPage ? ListView.Beginning : ListView.Contain)
        Qt.callLater(function() {
            if (startsPage)
                practiceList.positionViewAtIndex(index, ListView.Beginning)
            var item = practiceList.itemAtIndex(index)
            if (item) {
                if (initialText !== undefined && initialText !== "")
                    item.setInputText(initialText)
                item.focusInput()
            }
        })
    }

    function joinedPracticeText() {
        return practiceTexts.join("")
    }

    function updatePracticeScore() {
        if (practiceDone || !activeLesson.text)
            return
        var typed = joinedPracticeText()
        practiceResult = backend.liveScore(activeLesson.text, typed, activeLesson.language)
        if (typed === activeLesson.text) {
            practiceResult = backend.finishPractice(activeLesson.id, activeLesson.text, typed, activeLesson.language, courseDifficulty)
            practiceDone = true
            backend.playFeedback("complete")
        }
    }

    function filteredLessons() {
        var query = searchQuery.trim().toLowerCase()
        return backend.lessons.filter(function(item) {
            var matchesDifficulty = item.difficulty === courseDifficulty
            var matchesType = courseType === "全部" || item.content_type === courseType
            var haystack = ((item.title || "") + " " + (item.subtitle || "") + " " +
                            (item.author || "") + " " + (item.text || "")).toLowerCase()
            return matchesDifficulty && matchesType && (!query || haystack.indexOf(query) >= 0)
        })
    }

    function showNotice(message, success) {
        if (!message) return
        noticeText = message
        noticeSuccess = success
        noticeBanner.visible = true
        noticeTimer.restart()
    }

    function openLesson(lesson) {
        activeLesson = lesson
        practiceResult = ({accuracy: 100, speed: 0, speed_unit: lesson.language === "en" ? "WPM" : "字/分钟", errors: 0})
        practiceDone = false
        practiceGeneration++
        courseDifficulty = lesson.difficulty || courseDifficulty
        practiceParts = splitPracticeText(lesson.text || "", lesson.language)
        practiceTexts = practiceParts.map(function() { return "" })
        backend.startPractice()
        page = 2
        Qt.callLater(function() {
            var first = practiceList.itemAtIndex(0)
            if (first) first.focusInput()
        })
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.preferredWidth: 218
            Layout.fillHeight: true
            color: "#25213D"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 10

                RowLayout {
                    Layout.bottomMargin: 24
                    Rectangle { width: 46; height: 46; radius: 15; color: "#7668F0"
                        Text { anchors.centerIn: parent; text: "⌨"; font.pixelSize: 25; color: "white" }
                    }
                    Column {
                        Text { text: "打字星球"; color: "white"; font.pixelSize: 20; font.bold: true }
                        Text { text: "每一键都有进步"; color: "#ABA5CB"; font.pixelSize: 11 }
                    }
                }

                Repeater {
                    model: [{icon:"⌂", label:"学习主页", p:0}, {icon:"✦", label:"课程地图", p:1},
                            {icon:"♜", label:"趣味游戏", p:3}, {icon:"⚙", label:"设置", p:4}]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; height: 48; radius: 14
                        color: root.page === modelData.p ? "#484064" : navMouse.containsMouse ? "#342E50" : "transparent"
                        Row { anchors.verticalCenter: parent.verticalCenter; leftPadding: 15; spacing: 13
                            Text { text: modelData.icon; color: root.page === modelData.p ? "#B9AEFF" : "#8F88AD"; font.pixelSize: 18 }
                            Text { text: modelData.label; color: root.page === modelData.p ? "white" : "#C4BEDA"; font.pixelSize: 14; font.weight: Font.Medium }
                        }
                        MouseArea { id: navMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.page = modelData.p }
                    }
                }
                Item { Layout.fillHeight: true }
                Rectangle { Layout.fillWidth: true; height: 94; radius: 18; color: "#332D4D"
                    Column { anchors.centerIn: parent; spacing: 7
                        Text { text: "已收集  ★ " + backend.summary.stars; color: "#FFD66B"; font.pixelSize: 15; font.bold: true }
                        Text { text: backend.summary.completed + " / " + backend.summary.total + " 课程完成"; color: "#AAA3C3"; font.pixelSize: 11 }
                    }
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.page

            // Home
            Flickable {
                contentHeight: homeColumn.height + 64; clip: true
                ColumnLayout {
                    id: homeColumn; width: parent.width - 72; x: 36; y: 30; spacing: 22
                    RowLayout {
                        Layout.fillWidth: true
                        Column { Layout.fillWidth: true
                            Text { text: "你好，打字小行家！"; color: "#25213D"; font.pixelSize: 29; font.bold: true }
                            Text { text: "今天也来完成一次轻松的键盘旅行吧。"; color: "#777189"; font.pixelSize: 14 }
                        }
                        AppButton { text: "继续学习  →"; onClicked: root.page = 1 }
                    }
                    Rectangle {
                        Layout.fillWidth: true; height: 190; radius: 26
                        gradient: Gradient { GradientStop { color: "#7062E9"; position: 0 } GradientStop { color: "#897DF3"; position: 1 } }
                        RowLayout { anchors.fill: parent; anchors.margins: 28
                            ColumnLayout { Layout.fillWidth: true
                                Text { text: "今天的挑战"; color: "#DCD8FF"; font.pixelSize: 14 }
                                Text { text: "保持准确，速度自然会来"; color: "white"; font.pixelSize: 24; font.bold: true }
                                Text { text: "先完成一节 3–5 分钟的小课程，再去游戏里大显身手。"; color: "#E6E3FF"; font.pixelSize: 13 }
                                AppButton { text: "开始一课"; fillColor: "white"; textColor: "#5E50D8"; onClicked: root.page = 1 }
                            }
                            Text { text: "🚀"; font.pixelSize: 86; rotation: -8 }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 16
                        Repeater {
                            model: [{n:backend.summary.completed, t:"已完成课程", c:"#6657E8", i:"✓"},
                                    {n:backend.summary.stars, t:"收集星星", c:"#F2A93B", i:"★"},
                                    {n:backend.summary.attempts, t:"练习次数", c:"#27B99A", i:"↗"}]
                            delegate: Panel {
                                required property var modelData
                                Layout.fillWidth: true; height: 112
                                Row { anchors.centerIn: parent; spacing: 15
                                    Rectangle { width: 48; height: 48; radius: 15; color: modelData.c + "20"
                                        Text { anchors.centerIn: parent; text: modelData.i; color: modelData.c; font.pixelSize: 22; font.bold: true }
                                    }
                                    Column { Text { text: modelData.n; color: "#2D2942"; font.pixelSize: 25; font.bold: true }
                                        Text { text: modelData.t; color: "#817B91"; font.pixelSize: 12 }
                                    }
                                }
                            }
                        }
                    }
                    Text { text: "推荐课程"; color: "#302B47"; font.pixelSize: 20; font.bold: true }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 16
                        Repeater { model: backend.lessons.slice(0, 3)
                            delegate: Panel {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true; height: 145
                                Column { anchors.fill: parent; anchors.margins: 19; spacing: 8
                                    Text { text: modelData.language === "en" ? "ABC" : "拼音"; color: root.colors[index]; font.bold: true; font.pixelSize: 13 }
                                    Text { text: modelData.title; color: "#302B47"; font.bold: true; font.pixelSize: 17 }
                                    Text { text: modelData.subtitle; color: "#817B91"; font.pixelSize: 11 }
                                    Text { text: "★".repeat(modelData.stars) + "☆".repeat(3-modelData.stars); color: "#F2A93B"; font.pixelSize: 15 }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openLesson(modelData) }
                            }
                        }
                    }
                }
            }

            // Lessons
            Item {
                ColumnLayout { anchors.fill: parent; anchors.margins: 34; spacing: 18
                    RowLayout { Layout.fillWidth: true
                        Column { Layout.fillWidth: true
                            Text { text: "课程地图"; color: "#25213D"; font.pixelSize: 29; font.bold: true }
                            Text { text: "从基准键开始，按自己的节奏一路前进。"; color: "#777189"; font.pixelSize: 14 }
                        }
                        AppButton { text: "＋ 导入文章"; fillColor: "#EAE7FA"; textColor: "#5D50D3"; onClicked: { root.importDifficulty = root.courseDifficulty; root.importPath = ""; root.importFilename = ""; importTitle.text = ""; importAuthor.text = ""; importDialog.open() } }
                    }
                    RowLayout { Layout.fillWidth: true
                        DifficultyPicker { moduleKey: "course"; selected: root.courseDifficulty; onSelectedByUser: function(value) { root.courseDifficulty = value } }
                        Item { Layout.fillWidth: true }
                        TextField {
                            Layout.preferredWidth: 220; placeholderText: "搜索标题、作者或正文"
                            onTextChanged: root.searchQuery = text
                            background: Rectangle { color: "white"; radius: 11; border.color: parent.activeFocus ? "#786BEF" : "#DED9EC" }
                        }
                        ComboBox { model: ["全部","课程","原创短文","古诗","古文","现代公版","自定义文章"]; onCurrentTextChanged: root.courseType = currentText }
                        Text { text: root.filteredLessons().length + " 项"; color:"#817B91" }
                    }
                    ListView {
                        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12; clip: true
                        model: root.filteredLessons()
                        delegate: Panel {
                            required property var modelData
                            required property int index
                            width: ListView.view.width; height: 104
                            RowLayout { anchors.fill: parent; anchors.margins: 18; spacing: 18
                                Rectangle { width: 60; height: 60; radius: 19; color: root.colors[index % root.colors.length] + "20"
                                    Text { anchors.centerIn: parent; text: modelData.language === "en" ? "Aa" : "字"; color: root.colors[index % root.colors.length]; font.pixelSize: 21; font.bold: true }
                                }
                                Column { Layout.fillWidth: true; spacing: 5
                                    Row { spacing: 9
                                        Text { text: modelData.title; color: "#302B47"; font.pixelSize: 17; font.bold: true }
                                        Rectangle { width: levelText.width + 14; height: 23; radius: 8; color: "#F0EEF8"
                                            Text { id: levelText; anchors.centerIn: parent; text: modelData.level; color: "#706A80"; font.pixelSize: 10 }
                                        }
                                    }
                                    Text { text: modelData.subtitle; color: "#817B91"; font.pixelSize: 12 }
                                    Text { text: "★".repeat(modelData.stars) + "☆".repeat(3-modelData.stars); color: "#F2A93B"; font.pixelSize: 14 }
                                }
                                AppButton {
                                    visible: modelData.is_custom === true
                                    implicitWidth: 72; text: "删除"; fillColor: "#FCE8ED"; textColor: "#C94D6B"
                                    onClicked: {
                                        root.pendingDeleteLesson = modelData
                                        deletePassword.text = ""
                                        deletePasswordConfirm.text = ""
                                        deleteDialog.open()
                                    }
                                }
                                AppButton { text: modelData.stars ? "再练一次" : "开始课程"; onClicked: root.openLesson(modelData) }
                            }
                        }
                    }
                }
            }

            // Practice
            Item {
                ColumnLayout { anchors.fill: parent; anchors.margins: 34; spacing: 16
                    RowLayout { Layout.fillWidth: true
                        AppButton { text: "← 返回课程"; fillColor: "#EAE7FA"; textColor: "#5D50D3"; onClicked: root.page = 1 }
                        Item { Layout.fillWidth: true }
                        Text { text: activeLesson.title || "练习"; color: "#302B47"; font.pixelSize: 20; font.bold: true }
                        Item { Layout.fillWidth: true }
                        Text { text: activeLesson.language === "zh" ? "请开启系统拼音输入法" : "保持手指回到基准键"; color: "#817B91"; font.pixelSize: 12 }
                    }
                    RowLayout { Layout.fillWidth: true; spacing: 12
                        Repeater { model: [{v:(practiceResult.accuracy ?? 100) + "%", t:"准确率"}, {v:(practiceResult.speed ?? 0), t:practiceResult.speed_unit ?? "速度"}, {v:practiceResult.errors ?? 0, t:"错误"}]
                            delegate: Panel { required property var modelData; Layout.fillWidth: true; height: 78
                                Column { anchors.centerIn: parent
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.v; color: "#5F52DA"; font.pixelSize: 21; font.bold: true }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.t; color: "#817B91"; font.pixelSize: 10 }
                                }
                            }
                        }
                    }
                    Panel { Layout.fillWidth: true; Layout.fillHeight: true
                        ColumnLayout { anchors.fill: parent; anchors.margins: 18; spacing: 8
                            Text { text: "请照着输入"; color: "#817B91"; font.pixelSize: 12 }
                            ListView {
                                id: practiceList
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: 12
                                model: root.practiceParts
                                boundsBehavior: Flickable.StopAtBounds
                                delegate: Column {
                                    id: practiceRow
                                    required property string modelData
                                    required property int index
                                    width: ListView.view.width
                                    height: targetBox.height + rowInput.height + 6
                                    function focusInput() { rowInput.forceActiveFocus() }

                                    Rectangle {
                                        id: targetBox
                                        width: parent.width; height: 48; radius: 11
                                        color: "#F7F6FB"; border.color: "#ECE9F5"
                                        Row {
                                            anchors.left: parent.left; anchors.leftMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            Repeater {
                                                model: practiceRow.modelData.length
                                                delegate: Text {
                                                    id: targetChar
                                                    required property int index
                                                    readonly property string typed: root.practiceTexts[practiceRow.index] || ""
                                                    readonly property string expected: practiceRow.modelData.charAt(index)
                                                    readonly property bool entered: index < typed.length
                                                    readonly property bool correct: entered && typed.charAt(index) === expected
                                                    readonly property bool current: index === typed.length && rowInput.activeFocus
                                                    text: expected
                                                    color: correct ? "#B9B5C5" : entered ? "#E25578" : current ? "#6657E8" : "#3B3650"
                                                    opacity: correct ? 0.58 : 1
                                                    scale: current ? 1.08 : 1
                                                    font.pixelSize: activeLesson.language === "zh" ? 21 : 19
                                                    font.family: activeLesson.language === "en" ? "Menlo" : Qt.application.font.family
                                                    Behavior on color { ColorAnimation { duration: 180 } }
                                                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                                                    Rectangle {
                                                        anchors.left: parent.left; anchors.right: parent.right
                                                        anchors.bottom: parent.bottom; anchors.bottomMargin: -3
                                                        height: 2; radius: 1; color: "#7668F0"
                                                        visible: targetChar.current
                                                        SequentialAnimation on opacity {
                                                            running: targetChar.current; loops: Animation.Infinite
                                                            NumberAnimation { from: 1; to: 0.25; duration: 520 }
                                                            NumberAnimation { from: 0.25; to: 1; duration: 520 }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    TextArea {
                                        id: rowInput
                                        y: targetBox.height + 6
                                        width: parent.width; height: 48
                                        enabled: !root.practiceDone
                                        placeholderText: index === 0 ? (activeLesson.language === "zh" ? "输入这一行文字……" : "Type this line…") : ""
                                        wrapMode: TextEdit.NoWrap; selectByMouse: true
                                        color: "#302B47"
                                        font.pixelSize: activeLesson.language === "zh" ? 21 : 19
                                        font.family: activeLesson.language === "en" ? "Menlo" : Qt.application.font.family
                                        background: Rectangle {
                                            color: "white"; radius: 11; border.width: 2
                                            border.color: rowInput.activeFocus ? "#786BEF" : "#DED9EC"
                                        }
                                        function acceptCommittedText() {
                                            if (root.practiceDone || inputMethodComposing) return
                                            var value = text
                                            if (value.length > practiceRow.modelData.length &&
                                                    value.slice(0, practiceRow.modelData.length) === practiceRow.modelData) {
                                                var overflow = value.slice(practiceRow.modelData.length)
                                                text = practiceRow.modelData
                                                root.practiceTexts[index] = text
                                                Qt.callLater(function() {
                                                    root.focusPracticeIndex(index + 1, overflow)
                                                })
                                            } else {
                                                root.practiceTexts[index] = value
                                            }
                                            root.practiceTexts = root.practiceTexts.slice(0)
                                            root.updatePracticeScore()
                                            if (text === practiceRow.modelData && index + 1 < root.practiceParts.length) {
                                                Qt.callLater(function() {
                                                    root.focusPracticeIndex(index + 1)
                                                })
                                            }
                                        }
                                        onTextChanged: {
                                            acceptCommittedText()
                                        }
                                        onInputMethodComposingChanged: if (!inputMethodComposing) acceptCommittedText()
                                        Connections {
                                            target: root
                                            function onPracticeGenerationChanged() { rowInput.clear() }
                                        }
                                    }
                                    function setInputText(value) {
                                        rowInput.text = value
                                        rowInput.cursorPosition = rowInput.length
                                    }
                                }
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                            }
                            FullKeyboard { Layout.fillWidth: true; visible: activeLesson.language === "en"; targetText: activeLesson.text || ""; typedLength: root.joinedPracticeText().length; difficulty: root.courseDifficulty; showHands: true }
                            RowLayout { Layout.fillWidth: true
                                Text { text: activeLesson.source ? "来源：" + activeLesson.source : ""; color: "#9A94A7"; font.pixelSize: 10 }
                                Item { Layout.fillWidth: true }
                                AppButton { visible: !root.practiceDone; text: "重新开始"; fillColor: "#EAE7FA"; textColor: "#5D50D3"; onClicked: root.openLesson(activeLesson) }
                                AppButton { visible: root.practiceDone; text: "完成  " + "★".repeat(practiceResult.stars ?? 1); fillColor: "#27B99A"; onClicked: root.page = 1 }
                            }
                        }
                    }
                }
            }

            // Games
            Item {
                ColumnLayout { anchors.fill: parent; anchors.margins: 34; spacing: 20
                    Text { text: "趣味游戏"; color: "#25213D"; font.pixelSize: 29; font.bold: true }
                    Text { text: "把练习变成冒险——先准确，再加速。"; color: "#777189"; font.pixelSize: 14 }
                    GridLayout { Layout.fillWidth: true; Layout.fillHeight: true; columns: 2; columnSpacing: 16; rowSpacing: 16
                        GameCard { Layout.fillWidth: true; Layout.fillHeight: true; emoji: "☂"; artwork: "../resources/games/rain-cover.png"; title: "字母雨"; description: "在字母落地之前按下对应按键，训练反应与键位记忆。"; gradientA: "#6859E7"; gradientB: "#8D7DF5"; onPlay: { gameLoader.sourceComponent = letterRain; gameOverlay.visible = true } }
                        GameCard { Layout.fillWidth: true; Layout.fillHeight: true; emoji: "🏁"; artwork: "../resources/games/race-cover.png"; title: "打字竞速"; description: "和小船长一起乘风破浪，准确输入短句赢得水上比赛。"; gradientA: "#20AE91"; gradientB: "#65D2AE"; onPlay: { gameLoader.sourceComponent = typingRace; gameOverlay.visible = true } }
                        GameCard { Layout.fillWidth: true; Layout.fillHeight: true; emoji: "👾"; artwork: "../resources/games/space-cover.png"; title: "单词太空战"; description: "输入敌机单词发射光束，挑战连击与 Boss 波次。"; gradientA: "#E5668C"; gradientB: "#F09A6B"; onPlay: { gameLoader.sourceComponent = spaceWords; gameOverlay.visible = true } }
                        GameCard { Layout.fillWidth: true; Layout.fillHeight: true; emoji: "🚓"; artwork: "../resources/games/chase-cover.png"; title: "警察抓小偷"; description: "打出英文路标追击小偷，穿过街区、应对路障，在逃脱前完成抓捕！"; gradientA: "#3068BC"; gradientB: "#42B1A2"; onPlay: { gameLoader.sourceComponent = policeChase; gameOverlay.visible = true } }
                    }
                }
            }

            // Settings
            Item {
                ColumnLayout { anchors.fill: parent; anchors.margins: 34; spacing: 18
                    Text { text: "设置"; color: "#25213D"; font.pixelSize: 29; font.bold: true }
                    Panel { Layout.fillWidth: true; Layout.preferredHeight: 190
                        ColumnLayout { anchors.fill: parent; anchors.margins: 24
                            Switch { text: "开启音效"; checked: backend.soundEnabled; onToggled: backend.soundEnabled = checked }
                            Switch { text: "减少动画"; checked: backend.reducedMotion; onToggled: backend.reducedMotion = checked }
                            Text { text: "所有数据只保存在这台电脑，不需要账号，也不会上传。"; color: "#817B91"; font.pixelSize: 12 }
                        }
                    }
                    Panel { Layout.fillWidth: true; Layout.preferredHeight: 140
                        RowLayout { anchors.fill: parent; anchors.margins: 24
                            Column { Layout.fillWidth: true
                                Text { text: "学习数据备份"; color: "#302B47"; font.pixelSize: 16; font.bold: true }
                                Text { text: "导出 JSON 文件，方便保存成绩记录。"; color: "#817B91"; font.pixelSize: 12 }
                            }
                            ColumnLayout {
                                AppButton { text: "导出备份"; onClicked: backend.exportBackup() }
                                AppButton { text: "恢复备份"; fillColor: "#EAE7FA"; textColor: "#5D50D3"; onClicked: backend.importBackup() }
                            }
                        }
                    }
                    AppButton { text: "重置全部学习进度"; fillColor: "#FCE8ED"; textColor: "#C94D6B"; onClicked: resetDialog.open() }
                    Item { Layout.fillHeight: true }
                    Text { text: "打字星球 0.5.0 · 无广告 · 完全离线"; color: "#9A94A7"; font.pixelSize: 11 }
                }
            }
        }
    }

    Rectangle {
        id: gameOverlay; anchors.fill: parent; visible: false; color: "#E925213D"; z: 50
        MouseArea { anchors.fill: parent }
        Panel { width: Math.min(1080, parent.width - 48); height: Math.min(760, parent.height - 40); anchors.centerIn: parent
            Loader { id: gameLoader; anchors.fill: parent; anchors.margins: 16 }
            AppButton { anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 14; width: 44; text: "×"; fillColor: "#EEEAF7"; textColor: "#5D5670"; z: 10; onClicked: { gameOverlay.visible = false; gameLoader.sourceComponent = undefined } }
        }
    }

    Component { id: letterRain; LetterRain { onScreen: gameOverlay.visible; onCloseRequested: { gameOverlay.visible = false; gameLoader.sourceComponent = undefined } } }
    Component { id: typingRace; TypingRace { onScreen: gameOverlay.visible; onCloseRequested: { gameOverlay.visible = false; gameLoader.sourceComponent = undefined } } }
    Component { id: spaceWords; SpaceWords { onScreen: gameOverlay.visible } }
    Component { id: policeChase; PoliceChase { onScreen: gameOverlay.visible } }

    Timer { id: noticeTimer; interval: 3600; onTriggered: noticeBanner.visible = false }
    Rectangle {
        id: noticeBanner; visible: false; z: 100; height: 48; radius: 14
        width: Math.min(520, noticeLabel.implicitWidth + 56)
        anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.topMargin: 18
        color: root.noticeSuccess ? "#E3F7F1" : "#FCE8ED"
        border.color: root.noticeSuccess ? "#86D7C2" : "#E9A2B4"
        Text { id: noticeLabel; anchors.centerIn: parent; text: root.noticeText; color: root.noticeSuccess ? "#167A64" : "#B83E5D"; font.pixelSize: 13; font.bold: true }
    }

    Dialog {
        id: importDialog
        anchors.centerIn: parent; width: 480; modal: true
        title: "导入自定义文章"; standardButtons: Dialog.Cancel
        ColumnLayout {
            width: parent.width; spacing: 12
            Text { text: "选择 TXT 文件，然后可以修改标题并填写作者。"; color: "#5D5670"; wrapMode: Text.Wrap; Layout.fillWidth: true }
            RowLayout {
                Layout.fillWidth: true
                AppButton {
                    text: root.importPath ? "重新选择文件" : "选择 TXT 文件"
                    fillColor: "#EAE7FA"; textColor: "#5D50D3"
                    onClicked: {
                        var selection = backend.chooseTextFile()
                        if (selection.ok) {
                            root.importPath = selection.path
                            root.importFilename = selection.filename
                            importTitle.text = selection.title
                        }
                    }
                }
                Text { Layout.fillWidth: true; text: root.importFilename || "尚未选择文件"; elide: Text.ElideMiddle; color: root.importPath ? "#302B47" : "#9A94A7" }
            }
            TextField { id: importTitle; Layout.fillWidth: true; placeholderText: "文章标题（默认使用文件名）" }
            TextField { id: importAuthor; Layout.fillWidth: true; placeholderText: "作者（可选）" }
            Text { text: "文章难度"; color: "#302B47"; font.bold: true }
            RowLayout {
                Repeater {
                    model: [{key:"easy", label:"简单"}, {key:"normal", label:"普通"}, {key:"hard", label:"困难"}]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.preferredWidth: 118; Layout.preferredHeight: 40; radius: 11
                        color: root.importDifficulty === modelData.key ? "#6657E8" : "#ECE9F6"
                        Text { anchors.centerIn: parent; text: modelData.label; color: root.importDifficulty === modelData.key ? "white" : "#625C72"; font.bold: true }
                        MouseArea { anchors.fill: parent; onClicked: root.importDifficulty = modelData.key }
                    }
                }
            }
            Text { text: "相同正文只会保留一份；标题和作者都可以参与搜索。"; color: "#817B91"; font.pixelSize: 11 }
            AppButton {
                Layout.alignment: Qt.AlignRight; text: "导入文章"; enabled: root.importPath !== ""; opacity: enabled ? 1 : 0.5
                onClicked: {
                    var result = backend.importTextFile(root.importPath, root.importDifficulty, importTitle.text, importAuthor.text)
                    if (result.ok) {
                        root.courseDifficulty = result.difficulty
                        importDialog.close()
                    }
                    root.showNotice(result.message, result.ok)
                }
            }
        }
    }

    Dialog {
        id: deleteDialog
        anchors.centerIn: parent; width: 430; modal: true
        title: backend.hasDeletePassword ? "输入密码删除文章" : "设置家长删除密码"
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: {
            var result = backend.deleteCustomArticle(root.pendingDeleteLesson.id || "", deletePassword.text, deletePasswordConfirm.text)
            root.showNotice(result.message, result.ok)
        }
        ColumnLayout {
            width: parent.width; spacing: 12
            Text {
                Layout.fillWidth: true; wrapMode: Text.Wrap; color: "#5D5670"
                text: backend.hasDeletePassword
                      ? "确认删除《" + (root.pendingDeleteLesson.title || "") + "》？请输入家长密码。"
                      : "首次删除需要设置家长密码（至少 4 个字符），以后删除文章都要输入该密码。"
            }
            TextField { id: deletePassword; Layout.fillWidth: true; placeholderText: backend.hasDeletePassword ? "家长密码" : "设置新密码"; echoMode: TextInput.Password }
            TextField { id: deletePasswordConfirm; Layout.fillWidth: true; visible: !backend.hasDeletePassword; placeholderText: "再次输入新密码"; echoMode: TextInput.Password }
        }
    }

    Dialog {
        id: resetDialog
        anchors.centerIn: parent
        title: "确认重置学习进度？"
        modal: true
        standardButtons: Dialog.Yes | Dialog.Cancel
        onAccepted: backend.resetProgress()
        Text { width: 300; wrapMode: Text.Wrap; text: "课程星级、练习次数和游戏成绩都会清空。设置不会改变。"; color: "#5D5670" }
    }
}
