import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: game
    objectName: "typingRaceGame"
    signal closeRequested()
    property string difficulty: "normal"
    property bool onScreen: true
    property bool paused: false
    property var sets: ({easy:["A sunny day.","Keep a steady rhythm.","Small steps help."],normal:["Small steps make big progress.","Practice makes progress, one key at a time.","The stars shine brightly above us."],hard:["At 8:30, the careful pilot checked every signal before take-off.","Accuracy, patience, and rhythm—these three skills create lasting speed."]})
    property string target: ""
    property bool running: false
    property bool finished: false
    property bool won: false
    property bool saved: false
    property int elapsed: 0
    property real opponentProgress: 0
    property int combo: 0
    property int bestCombo: 0
    property int errors: 0
    property int furthest: 0
    property string previousText: ""
    property var config: backend.gameConfig["typing-race"][difficulty]
    readonly property bool playing: running && visible && onScreen && !paused
    readonly property bool motion: !backend.reducedMotion && playing
    readonly property real progress: correctLength() / Math.max(1, target.length)
    function correctLength() {
        var n = 0
        while (n < raceInput.text.length && n < target.length && raceInput.text[n] === target[n]) n++
        return n
    }
    function reset() {
        var list = sets[difficulty]
        target = list[Math.floor(Math.random() * list.length)]
        running = false
        raceInput.text = ""; previousText = ""
        finished = false; won = false; saved = false; paused = false
        elapsed = 0; opponentProgress = 0; combo = 0; bestCombo = 0; errors = 0; furthest = 0
        running = true
        raceInput.forceActiveFocus()
    }
    function complete(victory) {
        if (!running || saved) return
        won = victory === undefined ? raceInput.text === target : victory
        running = false; finished = true; saved = true
        var accuracy = Math.round(furthest / Math.max(1, furthest + errors) * 100)
        backend.saveGameScore("typing-race", won ? Math.max(10, 120 - elapsed * 2 + bestCombo) : Math.max(0, Math.round(progress * 50)), elapsed, difficulty, bestCombo, accuracy)
    }
    function acceptInput() {
        if (!playing || raceInput.inputMethodComposing) return
        var text = raceInput.text
        // Only new territory earns combo. Backspace/retyping cannot farm points.
        var n = correctLength()
        if (text.length > previousText.length) {
            if (n === text.length) {
                if (n > furthest) { combo += n - furthest; furthest = n; bestCombo = Math.max(bestCombo, combo) }
            } else { errors += Math.max(1, text.length - previousText.length); combo = 0 }
        }
        previousText = text
        if (text === target) complete(true)
    }
    Timer { interval: 200; repeat: true; running: game.playing; onTriggered: {
        game.opponentProgress = Math.min(1, game.opponentProgress + Number(game.config.opponent_speed) / 100)
        if (game.opponentProgress >= 1) game.complete(false)
    } }
    Timer { interval: 1000; repeat: true; running: game.playing; onTriggered: game.elapsed++ }
    Timer { id: waterClock; property real shift: 0; interval: 40; repeat: true; running: game.motion; onTriggered: shift = (shift + (game.combo >= 5 ? 5 : 2.5)) % 160 }

    Rectangle {
        anchors.fill: parent; radius: 22; color: "#F1FAF6"; clip: true
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 16; spacing: 9
            RowLayout {
                Layout.fillWidth: true
                Column {
                    Text { text: "小船冲冲冲"; color: "#20575A"; font.pixelSize: 25; font.bold: true }
                    Text { text: "指尖划桨 · 和小伙伴一起乘风破浪"; color: "#658785"; font.pixelSize: 11 }
                }
                Item { Layout.fillWidth: true }
                DifficultyPicker { Layout.rightMargin: 38; moduleKey: "typing-race"; onSelectedByUser: function(v) { var changed = game.difficulty !== v; game.difficulty = v; if (changed && game.running) game.reset() } }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Repeater {
                    model: [{label:"航行时间", value:game.elapsed + " 秒"}, {label:"连续正确", value:"×" + game.combo}, {label:"完成进度", value:Math.round(game.progress * 100) + "%"}]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; Layout.preferredHeight: 46; radius: 13; color: "#FFFFFF"
                        Row { anchors.centerIn: parent; spacing: 12
                            Text { text: modelData.label; color: "#73908B"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: modelData.value; color: "#22766E"; font.pixelSize: 19; font.bold: true }
                        }
                    }
                }
            }
            Rectangle {
                id: lagoon
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 180
                radius: 17; color: "#8EDBD9"; clip: true
                Canvas {
                    id: water; anchors.fill: parent
                    property real shift: waterClock.shift
                    onShiftChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        var c = getContext("2d"); c.reset()
                        var g = c.createLinearGradient(0,0,0,height); g.addColorStop(0,"#BDEDE5"); g.addColorStop(1,"#68C8D6"); c.fillStyle=g; c.fillRect(0,0,width,height)
                        c.fillStyle="#E8EBC4"; c.fillRect(0,0,width,12)
                        c.strokeStyle="#DEF9ED"; c.lineWidth=2
                        for(var lane=0;lane<4;lane++) {
                            var y=26+lane*(height-36)/4
                            for(var x=-160;x<width+160;x+=80) {
                                c.beginPath(); c.moveTo(x-shift,y+14); c.quadraticCurveTo(x+14-shift,y+20,x+30-shift,y+14); c.stroke()
                            }
                            if(lane>0){c.strokeStyle="#B3EEE5";c.setLineDash([5,9]);c.beginPath();c.moveTo(0,y-7);c.lineTo(width,y-7);c.stroke();c.setLineDash([]);c.strokeStyle="#DEF9ED"}
                        }
                    }
                }
                Rectangle { anchors.right: parent.right; anchors.rightMargin: 42; y: 14; width: 9; height: parent.height-28; color: "#BFFFFFFF"; Repeater { model: 20; Rectangle { required property int index; x: index % 2 ? 4 : 0; y: index * (parent.height / 20); width: 5; height: parent.height / 20; color: "#354B69" } } }
                Image { anchors.right: parent.right; anchors.rightMargin: 7; y: 8; width: Math.min(146, parent.width*.18); height: 55; source: "../resources/games/race-finish.png"; fillMode: Image.PreserveAspectFit }
                Repeater {
                    model: ["race-player", "race-rabbit", "race-duck", "race-cat"]
                    delegate: Item {
                        id: boat
                        required property int index
                        required property string modelData
                        width: Math.min(116, lagoon.width * .16); height: Math.max(39, (lagoon.height-18)/4)
                        property real position: index === 0 ? game.progress : Math.min(1, game.opponentProgress * (index === 1 ? 1 : index === 2 ? .91 : .83))
                        x: 8 + position * (lagoon.width-width-54)
                        y: 13 + index * (lagoon.height-20)/4
                        Behavior on x { enabled: !backend.reducedMotion && game.playing; NumberAnimation { duration: 190 } }
                        Image { visible: game.running && (boat.index !== 0 || game.combo >= 5); x: -35; y: parent.height*.2; width: 75; height: parent.height*.7; source: "../resources/games/race-boost.png"; fillMode: Image.PreserveAspectFit; opacity: .8 }
                        Image { anchors.fill: parent; source: "../resources/games/" + (boat.index === 0 ? (game.won ? "race-player-win" : game.combo >= 5 ? "race-player-fast" : "race-player") : boat.modelData) + ".png"; fillMode: Image.PreserveAspectFit }
                        Rectangle { visible: boat.index === 0; x: 3; y: 0; width: 28; height: 16; radius: 7; color: "#FFFBE5"; Text { anchors.centerIn: parent; text: "你"; color: "#36877B"; font.pixelSize: 10; font.bold: true } }
                    }
                }
                Image { visible: !game.running && !game.finished; anchors.fill: parent; source: "../resources/games/race-cover.png"; fillMode: Image.PreserveAspectFit; smooth:true
                    MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked:game.reset() }
                }
                Rectangle {
                    visible: game.finished || game.paused
                    anchors.centerIn: parent; width: Math.min(parent.width-30, 350); height: 82; radius: 18; color: "#F2FFFC"; opacity: .96
                    Column { anchors.centerIn: parent; spacing: 5
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: game.paused ? "休息一下，浪花等你" : game.won ? "太棒了！你率先冲线！" : "差一点点，下次一定！"; color: "#216B64"; font.pixelSize: 21; font.bold: true }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: game.paused ? "点击继续，再次出发" : "最佳连击 ×" + game.bestCombo + "  ·  成绩已保存"; color: "#76928B"; font.pixelSize: 12 }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 69; radius: 14; color: "#FFFFFF"
                Column { anchors.fill: parent; anchors.margins: 10; spacing: 3
                    Text { text: "本段航行口令"; color: "#68948D"; font.pixelSize: 10; font.bold: true }
                    Text { width: parent.width; text: game.target || "准备好了吗？输入英文，让小船向前！"; color: "#254B50"; font.family: "Menlo"; font.pixelSize: game.target.length > 60 ? 15 : 18; wrapMode: Text.Wrap }
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                TextField {
                    id: raceInput; objectName: "typingRaceInput"
                    Layout.fillWidth: true; Layout.preferredHeight: 46
                    enabled: game.playing; placeholderText: "在这里输入上方英文…"; font.family: "Menlo"; font.pixelSize: 16; color: "#254B50"
                    inputMethodHints: Qt.ImhPreferLatin | Qt.ImhNoPredictiveText
                    property bool valid: game.target.slice(0, text.length) === text
                    background: Rectangle { radius: 12; color: "white"; border.width: 2; border.color: raceInput.valid ? "#65BAA8" : "#EF8792" }
                    onTextEdited: game.acceptInput()
                    onInputMethodComposingChanged: if (!inputMethodComposing) game.acceptInput()
                }
                AppButton { visible: game.running; text: game.paused ? "继续" : "暂停"; fillColor: "#DBEEE6"; textColor: "#36766A"; onClicked: { game.paused = !game.paused; if (!game.paused) raceInput.forceActiveFocus() } }
                AppButton { text: game.finished ? "再来一局" : game.running ? "重新开始" : "开始比赛"; fillColor: "#239B83"; onClicked: game.reset() }
            }
            Text { text: "准确比着急更重要 · 连续正确输入 5 个字符，解锁水花加速！"; color: "#72958C"; font.pixelSize: 11 }
        }
    }
}
