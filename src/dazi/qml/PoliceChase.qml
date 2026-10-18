import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: chase
    objectName: "policeChaseGame"
    property bool paused: false
    readonly property bool ticking: active && visible && onScreen && !paused
    signal closeRequested()

    property string difficulty: "normal"
    property var state: ({phase: "ready", target: "", typed: "", progress: 0,
                          distance: 0, elapsed: 0, score: 0, combo: 0,
                          best_combo: 0, accuracy: 100, stage: 1, stages: 4,
                          lives: 3, message: "Ready for the chase?", difficulty: "normal",
                          thief_progress: 0, police_progress: 0, obstacles: []})
    property string checkpoint: ""
    property string lastSubmitted: ""
    property bool editing: false
    property int generation: 0
    property bool onScreen: true
    property bool suppressReset: false
    property bool syncingInput: false
    readonly property bool active: state.phase === "running"
    readonly property bool ended: state.phase === "won" || state.phase === "lost"
    readonly property bool motion: !backend.reducedMotion
    readonly property real roadShift: active && motion ? roadClock.shift : 0
    readonly property real gap: Number(state.distance || 0)
    // The engine reports route percentages in the range 0–100.
    readonly property real lead: Math.max(0, Math.min(1, Number(state.thief_progress || 0) / 100))
    readonly property real pursuit: Math.max(0, Math.min(1, Number(state.police_progress || 0) / 100))

    function applyState(next) {
        if (!next || !next.phase) return
        var oldTarget = checkpoint
        state = next
        checkpoint = String(next.target || "")
        if (checkpoint !== oldTarget || next.phase !== "running") generation++
        // Backend signals are synchronous. Defer clearing until the key event finishes.
        if (!suppressReset && (checkpoint !== oldTarget || next.phase !== "running")) {
            if (!editing) {
                syncingInput = true
                phraseInput.text = ""
                lastSubmitted = ""
                syncingInput = false
            } else {
                var expected = checkpoint
                var expectedGeneration = generation
                Qt.callLater(function() {
                    if (chase.checkpoint !== expected || chase.generation !== expectedGeneration) return
                    chase.syncingInput = true
                    phraseInput.text = ""
                    chase.lastSubmitted = ""
                    chase.syncingInput = false
                    if (chase.active) phraseInput.forceActiveFocus()
                })
            }
        }
        if (next.phase === "running" && checkpoint !== oldTarget && !editing)
            Qt.callLater(function() { if (chase.active) phraseInput.forceActiveFocus() })
    }

    function start() {
        paused = false
        syncingInput = true
        phraseInput.text = ""
        syncingInput = false
        checkpoint = ""
        lastSubmitted = ""
        generation++
        editing = false
        suppressReset = true
        var next = backend.pursuitStart(difficulty)
        suppressReset = false
        applyState(next)
        if (active) phraseInput.forceActiveFocus()
    }

    Component.onCompleted: applyState(backend.pursuitState)
    Connections {
        target: backend
        function onPursuitChanged() { chase.applyState(backend.pursuitState) }
    }

    Timer {
        interval: 1000
        repeat: true
        running: chase.ticking
        onTriggered: chase.applyState(backend.pursuitTick())
    }
    Timer {
        id: roadClock
        property real shift: 0
        interval: 40
        repeat: true
        running: chase.ticking && chase.motion
        onTriggered: shift = (shift + (Number(chase.state.combo || 0) >= 3 ? 5.6 : 2.8)) % 2444
    }

    Rectangle {
        anchors.fill: parent; radius: 22; color: "#F3F5FC"; clip: true
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 16; spacing: 8
            RowLayout {
                Layout.fillWidth: true
                Column {
                    Text { text: "城市追追追"; color: "#2B416A"; font.pixelSize: 25; font.bold: true }
                    Text { text: "收到新线索！敲对口令，追上小偷"; color: "#7A89A8"; font.pixelSize: 11 }
                }
                Item { Layout.fillWidth: true }
                DifficultyPicker {
                    Layout.rightMargin: 38; moduleKey: "police-chase"
                    onSelectedByUser: function(value) {
                        var changed = chase.difficulty !== value
                        chase.difficulty = value
                        if (changed && chase.active) chase.start()
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Repeater {
                    model: [{name:"剩余时间",value:chase.timeLabel(Math.max(0,Number(chase.state.time_limit || 0)-Number(chase.state.elapsed || 0)))}, {name:"任务得分",value:String(chase.state.score || 0)}, {name:"连击加速",value:"×" + (chase.state.combo || 0)}, {name:"目标距离",value:Math.round(chase.gap) + " 米"}]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; Layout.preferredHeight: 48; radius: 12; color: "#FFFFFF"
                        Column { anchors.centerIn: parent; spacing: 1
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.name; color: "#8290AA"; font.pixelSize: 10 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.value; color: "#3E6197"; font.pixelSize: 18; font.bold: true }
                        }
                    }
                }
            }
            Rectangle {
                id: scene
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 185
                radius: 16; color: "#C9E6F4"; clip: true
                Canvas {
                    id: city; anchors.fill: parent
                    property real shift: chase.roadShift
                    onShiftChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        var c=getContext("2d"); c.reset(); var w=width,h=height, horizon=h*.58
                        var sky=c.createLinearGradient(0,0,0,horizon); sky.addColorStop(0,"#BBDDF4");sky.addColorStop(1,"#F7EFD9");c.fillStyle=sky;c.fillRect(0,0,w,h)
                        c.fillStyle="#FFF4CB";c.beginPath();c.arc(w*.17,35,22,0,Math.PI*2);c.fill()
                        for(var layer=0;layer<2;layer++) {
                            var bw=layer?86:65, scroll=shift*(layer?.65:.22)
                            for(var i=-2;i<w/bw+3;i++) {
                                var bh=32+((i+18)*37%57),x=i*bw-scroll,y=horizon-bh-(layer?0:18)
                                c.fillStyle=layer?(i%2?"#AFCCD9":"#A4C1D2"):"#D0E1E8";c.fillRect(x,y,bw-8,bh+20)
                                if(layer){c.fillStyle="#EAF3EC";for(var a=9;a<bw-15;a+=18)for(var b=10;b<bh-4;b+=20)c.fillRect(x+a,y+b,7,9)}
                            }
                        }
                        c.fillStyle="#B9D0B4";c.fillRect(0,horizon-5,w,16)
                        c.fillStyle="#EDE5CF";c.fillRect(0,horizon+8,w,13)
                        c.fillStyle="#657789";c.fillRect(0,horizon+21,w,h)
                        c.fillStyle="#D7E1DE";c.fillRect(0,horizon+21,w,3)
                        c.fillStyle="#F6E9B9";for(var j=-1;j<w/94+2;j++)c.fillRect(j*94-shift,h*.85,46,3)
                        c.fillStyle="#A5B5BC";c.fillRect(0,h-9,w,9)
                    }
                }
                // Side-view cars share the horizontal street. Engine gap controls separation.
                Image {
                    id: patrol
                    width: Math.min(166, scene.width*.23); height: scene.height*.39
                    x: scene.width*.07 + chase.pursuit*scene.width*.14
                    y: scene.height*.59
                    source: "../resources/games/chase-police.png"; fillMode: Image.PreserveAspectFit
                    Behavior on x { enabled: chase.motion && chase.ticking; NumberAnimation { duration: 450 } }
                    Image { visible: chase.active && Number(chase.state.combo || 0) >= 3; x: -width*.53; y: parent.height*.27; width: parent.width*.7; height: parent.height*.58; z: -1; source: "../resources/games/chase-boost.png"; fillMode: Image.PreserveAspectFit }
                }
                Image {
                    id: thief
                    width: Math.min(145, scene.width*.21); height: scene.height*.34
                    x: Math.min(scene.width-width-10, patrol.x + patrol.width*.78 + Math.max(0,Math.min(1,chase.gap/150))*scene.width*.36 + chase.lead*scene.width*.05)
                    y: scene.height*.52
                    source: "../resources/games/chase-thief.png"; fillMode: Image.PreserveAspectFit
                    Behavior on x { enabled: chase.motion && chase.ticking; NumberAnimation { duration: 450 } }
                    Image { visible: chase.active; x: -30; y: parent.height*.43; width: 65; height: parent.height*.6; z: -1; source: "../resources/games/chase-smoke.png"; fillMode: Image.PreserveAspectFit; opacity: .7 }
                }
                Rectangle {
                    x: 10; y: 10; width: routeText.width+20; height: 26; radius: 10; color: "#F5FAFF"
                    Text { id: routeText; anchors.centerIn: parent; text: "街区 " + chase.state.stage + " / " + chase.state.stages; color: "#456995"; font.pixelSize: 11; font.bold: true }
                }
                Row {
                    anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10; spacing: 3
                    Repeater { model: Number(backend.gameConfig["police-chase"][chase.difficulty].lives); Image { required property int index; width: 24; height: 24; source: "../resources/games/heart.png"; fillMode: Image.PreserveAspectFit; opacity: index < Number(chase.state.lives || 0) ? 1 : .22 } }
                }
                Image {
                    visible: chase.active
                    anchors.horizontalCenter: parent.horizontalCenter; y: 13
                    width: Math.min(290, parent.width*.44); height: parent.height*.4
                    source: "../resources/games/chase-sign.png"; fillMode: Image.Stretch
                    Text { anchors.fill: parent; anchors.margins: 15; text: chase.checkpoint; color: "#FFFFFF"; font.family: "Menlo"; font.pixelSize: chase.checkpoint.length>35?12:16; font.bold: true; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                Image { visible: !chase.active && !chase.ended; anchors.fill: parent; source: "../resources/games/chase-cover.png"; fillMode: Image.PreserveAspectFit; smooth:true
                    MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked:chase.start() }
                }
                Rectangle {
                    visible: chase.ended || chase.paused
                    anchors.fill: parent; color: "#DBF1F5FB"
                    Image { visible: chase.state.phase === "won"; anchors.left: parent.left; anchors.leftMargin: parent.width*.08; anchors.verticalCenter: parent.verticalCenter; width: parent.width*.35; height: parent.height*.85; source: "../resources/games/chase-caught.png"; fillMode: Image.PreserveAspectFit }
                    Column {
                        x: chase.state.phase === "won" ? parent.width*.47 : 0
                        width: chase.state.phase === "won" ? parent.width*.5 : parent.width
                        anchors.verticalCenter: parent.verticalCenter; spacing: 7
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: chase.paused ? "巡逻暂停中" : chase.state.phase === "won" ? "抓到啦！任务完成" : "小偷溜走了，再追一次！"; color: "#315885"; font.pixelSize: 22; font.bold: true }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: chase.paused ? "休息一下，点击继续" : "本次得分 " + (chase.state.score || 0) + " · 最佳连击 ×" + (chase.state.best_combo || 0); color: "#7187A2"; font.pixelSize: 12 }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 7
                Text { text: "追踪路线"; color: "#6A7F9B"; font.pixelSize: 11 }
                Repeater {
                    model: Math.max(1,Math.min(12,Number(chase.state.stages || 4)))
                    delegate: Rectangle {
                        required property int index
                        Layout.fillWidth: true; Layout.preferredHeight: 7; radius: 4
                        color: index < Number(chase.state.stage || 1)-1 ? "#53B8A0" : index === Number(chase.state.stage || 1)-1 ? "#618CD5" : "#DCE4F1"
                    }
                }
                Text { text: Math.round(chase.pursuit*100) + "%"; color: "#537ABD"; font.pixelSize: 11 }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 65; radius: 13; color: "white"
                Column { anchors.fill: parent; anchors.margins: 10; spacing: 3
                    Text { text: chase.ended ? "本次行动已结束" : "路牌口令 · 准确输入即可加速"; color: "#7B91AD"; font.pixelSize: 10; font.bold: true }
                    Text { width: parent.width; text: chase.state.target || "准备出发！用键盘守护城市"; color: "#2D4968"; font.family: "Menlo"; font.pixelSize: 17; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight }
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                TextField {
                    id: phraseInput; objectName: "policeChaseInput"
                    Layout.fillWidth: true; Layout.preferredHeight: 44
                    enabled: chase.ticking
                    placeholderText: chase.active ? "输入路牌上的英文口令…" : "点击出发，接收第一条线索"
                    font.family: "Menlo"; font.pixelSize: 15; color: "#263750"; selectByMouse: true
                    inputMethodHints: Qt.ImhPreferLatin | Qt.ImhNoPredictiveText
                    property bool correctPrefix: chase.checkpoint.indexOf(text) === 0 && text.indexOf(String(chase.state.typed || "")) === 0
                    background: Rectangle { radius: 11; color: "#FFFFFF"; border.width: 2; border.color: !phraseInput.enabled ? "#DFE6F1" : phraseInput.correctPrefix ? "#91B5E9" : "#E87680" }
                    onTextEdited: {
                        if (!chase.ticking || chase.syncingInput || inputMethodComposing) return
                        chase.lastSubmitted = text
                        chase.editing = true
                        backend.pursuitSubmit(text)
                        chase.editing = false
                    }
                    onInputMethodComposingChanged: {
                        if (!inputMethodComposing && chase.ticking && !chase.syncingInput && text !== chase.lastSubmitted) {
                            chase.lastSubmitted = text
                            chase.editing = true
                            backend.pursuitSubmit(text)
                            chase.editing = false
                        }
                    }
                }
                AppButton { visible: chase.active; text: chase.paused ? "继续" : "暂停"; fillColor: "#E1E9F6"; textColor: "#4C6C9C"; onClicked: { chase.paused = !chase.paused; if (!chase.paused) phraseInput.forceActiveFocus() } }
                AppButton { text: chase.active ? "重新出发" : chase.ended ? "再追一次" : "开始追逐"; fillColor: "#537ED3"; onClicked: chase.start() }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: chase.ended ? (chase.state.phase === "won" ? "城市恢复平静，你就是键盘小英雄！" : "调整节奏，准确输入，下次一定能追上！") : "连续正确输入，缩短距离；留意爱心和街区进度。"; color: "#7B8EA6"; font.pixelSize: 10; elide: Text.ElideRight }
                Text { text: "准确率 " + (chase.state.accuracy === undefined ? 100 : Math.round(chase.state.accuracy)) + "%"; color: "#6F85A0"; font.pixelSize: 10 }
            }
        }
    }
    function timeLabel(seconds) {
        var count = Math.max(0, Math.floor(Number(seconds || 0)))
        return Math.floor(count / 60) + ":" + (count % 60 < 10 ? "0" : "") + count % 60
    }
}
