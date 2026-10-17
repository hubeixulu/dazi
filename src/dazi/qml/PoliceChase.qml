import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: chase
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
        running: chase.active && chase.visible && chase.onScreen
        onTriggered: chase.applyState(backend.pursuitTick())
    }
    Timer {
        id: roadClock
        property real shift: 0
        interval: 40
        repeat: true
        running: chase.active && chase.visible && chase.onScreen && chase.motion
        onTriggered: shift = (shift + 2.8) % 94
    }

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: "#F5F6FB"
        border.color: "#E5E9F1"
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 9

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Rectangle {
                    Layout.preferredWidth: 44; Layout.preferredHeight: 44
                    radius: 14; color: "#DFEBFF"
                    Text { anchors.centerIn: parent; text: "✦"; color: "#3F6FDE"; font.pixelSize: 26; font.bold: true }
                }
                ColumnLayout {
                    spacing: 1
                    Text { text: "POLICE CHASE"; color: "#24334F"; font.pixelSize: 21; font.bold: true; font.letterSpacing: 1.5 }
                    Text { text: "Type the dispatch, close the gap."; color: "#71809B"; font.pixelSize: 11 }
                }
                Item { Layout.fillWidth: true }
                DifficultyPicker {
                    moduleKey: "police-chase"
                    onSelectedByUser: function(value) {
                        // Picker emits once on construction too: only clicks mid-chase restart.
                        var changed = chase.difficulty !== value
                        chase.difficulty = value
                        if (changed && chase.active) chase.start()
                    }
                }
                Item { Layout.preferredWidth: 36 }
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Repeater {
                    model: [
                        {name: "TIME", value: chase.timeLabel(chase.state.elapsed), accent: "#4769C9"},
                        {name: "SCORE", value: String(chase.state.score || 0), accent: "#223B60"},
                        {name: "COMBO", value: "×" + String(chase.state.combo || 0), accent: "#D18139"},
                        {name: "GAP", value: Math.round(chase.gap) + " m", accent: "#C94E63"}
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; Layout.preferredHeight: 53
                        radius: 12; color: "#FFFFFF"; border.color: "#E5EAF3"
                        Column {
                            anchors.centerIn: parent; spacing: 2
                            Text { text: modelData.name; color: "#8591A8"; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.2; anchors.horizontalCenter: parent.horizontalCenter }
                            Text { text: modelData.value; color: modelData.accent; font.pixelSize: 18; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                        }
                    }
                }
            }

            Item {
                id: scene
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.minimumHeight: 142
                clip: true
                Rectangle { anchors.fill: parent; radius: 16; color: "#DDECEB" }
                // Layered verge and lane edges follow the same curve as the road.
                Canvas {
                    id: road
                    anchors.fill: parent
                    property real shift: chase.roadShift
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onShiftChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        var w = width, h = height
                        function center(y) { return w / 2 + Math.sin(y / 97 + shift / 124) * Math.min(35, w * .055) }
                        function band(half, color) {
                            ctx.beginPath()
                            for (var y = -8; y <= h + 10; y += 5) {
                                if (y === -8) ctx.moveTo(center(y) - half, y)
                                else ctx.lineTo(center(y) - half, y)
                            }
                            for (var y2 = h + 10; y2 >= -8; y2 -= 5) ctx.lineTo(center(y2) + half, y2)
                            ctx.closePath(); ctx.fillStyle = color; ctx.fill()
                        }
                        var half = Math.min(119, w * .23)
                        band(half + 10, "#C6DAD4")
                        band(half + 5, "#FFFDF5")
                        band(half, "#303C51")
                        ctx.strokeStyle = "#A9B5C7"; ctx.lineWidth = 2
                        ctx.setLineDash([18, 19]); ctx.lineDashOffset = -shift
                        ctx.beginPath()
                        for (var ly = -8; ly < h + 10; ly += 4) {
                            if (ly === -8) ctx.moveTo(center(ly), ly)
                            else ctx.lineTo(center(ly), ly)
                        }
                        ctx.stroke(); ctx.setLineDash([])
                    }
                }
                Repeater {
                    model: 4
                    delegate: Rectangle {
                        required property int index
                        width: 18; height: 5; radius: 2; color: "#FFFFFF"
                        opacity: .7
                        y: ((index * 97 + chase.roadShift * 2) % (scene.height + 24)) - 12
                        x: scene.width / 2 + Math.sin(y / 97 + chase.roadShift / 124) * Math.min(35, scene.width * .055)
                           + (index % 2 ? -1 : 1) * Math.min(126, scene.width * .25) - width / 2
                    }
                }
                Repeater {
                    model: chase.state.obstacles || []
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: 38; height: 12; radius: 4
                        color: "#FFC05F"; border.color: "#AD7430"; border.width: 2
                        property real position: typeof modelData === "number" ? modelData : Number(modelData.position || 0)
                        x: scene.width / 2 + Math.sin(y / 97 + chase.roadShift / 124) * Math.min(35, scene.width * .055)
                           + ((index % 2) ? 53 : -53) - width / 2
                        y: ((position * scene.height + chase.roadShift * 2) % (scene.height + 16)) - 8
                        Text { anchors.centerIn: parent; text: "▰ ▰"; color: "#74461E"; font.pixelSize: 8 }
                    }
                }
                // Higher police progress lifts the patrol car toward the escaping car.
                Item {
                    id: thief
                    width: 46; height: 46
                    y: Math.max(7, Math.min(scene.height - height - 7,
                         scene.height * (.30 - chase.lead * .10)))
                    x: scene.width / 2 + Math.sin((y + height / 2) / 97 + chase.roadShift / 124) * Math.min(35, scene.width * .055) + 39 - width / 2
                    Behavior on y { enabled: chase.motion; NumberAnimation { duration: 400 } }
                    Rectangle { anchors.centerIn: parent; width: 31; height: 43; radius: 9; color: "#F17E67"; border.color: "#C75150"; border.width: 2
                        Rectangle { x: 5; y: 8; width: 21; height: 12; radius: 4; color: "#533C57" }
                        Rectangle { x: 5; y: 27; width: 21; height: 8; radius: 3; color: "#F8BE95" }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; y: -10; text: "SUSPECT"; color: "#FFF"; font.pixelSize: 8; font.bold: true }
                }
                Item {
                    id: patrol
                    width: 48; height: 49
                    y: Math.max(49, Math.min(scene.height - height - 5,
                         scene.height * (.82 - chase.pursuit * .37)))
                    x: scene.width / 2 + Math.sin((y + height / 2) / 97 + chase.roadShift / 124) * Math.min(35, scene.width * .055) - 42 - width / 2
                    Behavior on y { enabled: chase.motion; NumberAnimation { duration: 430 } }
                    Rectangle { anchors.centerIn: parent; width: 33; height: 43; radius: 9; color: "#FBFCFF"; border.color: "#B4C4D9"; border.width: 2
                        Rectangle { x: 5; y: 8; width: 23; height: 15; radius: 4; color: "#4D6685" }
                        Rectangle { x: 5; y: 28; width: 23; height: 8; radius: 3; color: "#2F619B" }
                        Rectangle { x: 10; y: 5; width: 7; height: 4; radius: 2; color: "#EF6266" }
                        Rectangle { x: 17; y: 5; width: 7; height: 4; radius: 2; color: "#6298F4" }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; y: 44; text: "YOU"; color: "#FFF"; font.pixelSize: 8; font.bold: true }
                }
                Rectangle {
                    anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 11
                    width: stagePill.width + 18; height: 26; radius: 9; color: "#F9FCFF"
                    Text { id: stagePill; anchors.centerIn: parent; text: "ROUTE  " + chase.state.stage + " / " + chase.state.stages; color: "#304567"; font.pixelSize: 10; font.bold: true }
                }
                Rectangle {
                    visible: chase.state.lives !== undefined && chase.state.lives !== null
                    anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 11
                    width: heartText.width + 18; height: 26; radius: 9; color: "#F9FCFF"
                    Text { id: heartText; anchors.centerIn: parent; text: "♥  " + chase.state.lives; color: "#DB6672"; font.pixelSize: 12; font.bold: true }
                }
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 7
                Text { text: "DISPATCH ROUTE"; color: "#6D7C98"; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1 }
                Repeater {
                    model: Math.max(1, Math.min(12, Number(chase.state.stages || 4)))
                    delegate: Rectangle {
                        required property int index
                        Layout.fillWidth: true; Layout.preferredHeight: 7; radius: 4
                        color: index < Number(chase.state.stage || 1) - 1 ? "#4ECAAB"
                             : index === Number(chase.state.stage || 1) - 1 ? "#5983E5" : "#DFE6F1"
                    }
                }
                Text { text: Math.round(Math.max(0, Math.min(1, Number(chase.state.progress || 0))) * 100) + "%"; color: "#5274BE"; font.pixelSize: 11; font.bold: true }
            }

            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 73
                radius: 13; color: "#FFFFFF"; border.color: "#E5EAF3"
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 11; spacing: 3
                    Text { text: chase.ended ? (chase.state.phase === "won" ? "CASE CLOSED" : "SUSPECT ESCAPED") : "INCOMING TRANSMISSION";
                           color: chase.ended ? "#D26770" : "#6B82AE"; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.4 }
                    Text {
                        Layout.fillWidth: true
                        text: chase.state.target || "Press START CHASE to receive your first dispatch."
                        color: "#263750"; font.family: "Menlo"; font.pixelSize: 16; font.bold: true
                        wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 9
                TextField {
                    id: phraseInput
                    Layout.fillWidth: true; Layout.preferredHeight: 44
                    enabled: chase.active
                    placeholderText: chase.active ? "Type the phrase exactly…" : "Start the chase to type"
                    font.family: "Menlo"; font.pixelSize: 14
                    color: "#263750"; selectByMouse: true
                    inputMethodHints: Qt.ImhPreferLatinInput | Qt.ImhNoPredictiveText
                    property bool correctPrefix: chase.checkpoint.indexOf(text) === 0 && text.indexOf(String(chase.state.typed || "")) === 0
                    background: Rectangle {
                        radius: 11; color: "#FFFFFF"; border.width: 2
                        border.color: !phraseInput.enabled ? "#DFE6F1" : phraseInput.correctPrefix ? "#91B5E9" : "#E87680"
                    }
                    onTextEdited: {
                        if (!chase.active || chase.syncingInput || inputMethodComposing) return
                        chase.lastSubmitted = text
                        chase.editing = true
                        backend.pursuitSubmit(text)
                        chase.editing = false
                    }
                    onInputMethodComposingChanged: {
                        if (!inputMethodComposing && chase.active && !chase.syncingInput && text !== chase.lastSubmitted) {
                            chase.lastSubmitted = text
                            chase.editing = true
                            backend.pursuitSubmit(text)
                            chase.editing = false
                        }
                    }
                }
                AppButton {
                    Layout.preferredWidth: 127; Layout.preferredHeight: 44
                    text: chase.active ? "RESTART" : chase.ended ? "TRY AGAIN" : "START CHASE"
                    fillColor: chase.active ? "#E8EEF9" : "#4D71D9"
                    textColor: chase.active ? "#43609A" : "#FFFFFF"
                    font.pixelSize: 11
                    onClicked: chase.start()
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: chase.state.message || (chase.active ? "Keep your eyes on the road and your hands on the keys." : "Ready when you are.")
                    color: chase.state.phase === "lost" ? "#C65D65" : "#687B99"
                    font.pixelSize: 11; elide: Text.ElideRight
                }
                Text { text: "BEST ×" + (chase.state.best_combo || 0) + "   ·   " + (chase.state.accuracy === undefined ? 100 : Math.round(chase.state.accuracy)) + "% accuracy";
                       color: "#7F8BA0"; font.pixelSize: 10 }
            }
        }
    }

    function timeLabel(seconds) {
        var count = Math.max(0, Math.floor(Number(seconds || 0)))
        return Math.floor(count / 60) + ":" + (count % 60 < 10 ? "0" : "") + count % 60
    }
}
