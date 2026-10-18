import QtQuick
import QtQuick.Layouts

Item {
    id: game
    objectName: "letterRainGame"
    signal closeRequested()
    property var drops: []
    property int score: 0
    property int lives: 3
    property int seconds: 45
    property bool running: false
    property bool paused: false
    property bool onScreen: true
    readonly property bool playing: running && !paused && visible && onScreen
    property bool resultSaved: false
    property string gameState: running ? (paused ? "paused" : "playing") : (resultSaved ? "finished" : "ready")
    property string difficulty: "normal"
    property int combo: 0
    property int bestCombo: 0
    property int attempts: 0
    property int hits: 0
    property int correctChars: 0
    property string buffer: ""
    property string mood: "idle"
    property real mascotX: 0.5
    property var splashes: []
    property int nextId: 0
    property var config: backend.gameConfig["letter-rain"][difficulty]
    property string alphabet: config.mode === "home" ? "asdfjkl;" : "asdfjkl;qwertyuiopzxcvbnm"
    property var words: ["cat", "sun", "tree", "book", "green", "happy", "planet", "window", "school", "friend"]
    readonly property bool reducedMotion: backend.reducedMotion
    function start() { reset() }
    function reset() {
        drops=[]; splashes=[]; nextId=0; score=0; lives=config.lives; seconds=45
        combo=0; bestCombo=0; attempts=0; hits=0; correctChars=0; buffer=""
        mood="idle"; mascotX=0.5; moodTimer.stop(); paused=false; resultSaved=false; running=true
        spawn(); forceActiveFocus()
    }
    function spawn() {
        if (!running || paused) return
        var token=config.mode==="words" ? words[Math.floor(Math.random()*words.length)] : alphabet[Math.floor(Math.random()*alphabet.length)]
        var next=drops.slice()
        next.push({id:nextId++, token:token, x:0.08+Math.random()*0.84, y:-45})
        drops=next
    }
    function react(kind, x) { mood=kind; mascotX=x; moodTimer.restart() }
    function advance() {
        if (!running || paused) return
        var next=[], missed=0
        for (var i=0;i<drops.length;i++) {
            var d=drops[i], ny=d.y+config.fall_step+score/160
            if(ny>playfield.height-112) { missed++; react("sad",d.x) }
            else next.push({id:d.id,token:d.token,x:d.x,y:ny})
        }
        drops=next
        var fx=[]
        for(var j=0;j<splashes.length;j++) { var s=splashes[j]; if(s.age<14)fx.push({x:s.x,y:s.y,age:s.age+1,points:s.points}) }
        splashes=fx
        if(missed) { lives=Math.max(0,lives-missed); combo=0; buffer="" }
        if(lives<=0)finish()
    }
    function hitAt(index) {
        if (!running || paused || index<0 || index>=drops.length) return
        var d=drops[index], next=drops.slice(); next.splice(index,1); drops=next
        hits++; combo++; bestCombo=Math.max(bestCombo,combo)
        var points=10+Math.min(20,combo*2); score+=points
        var fx=splashes.slice(); fx.push({x:d.x,y:d.y,age:0,points:points}); splashes=fx
        buffer=""; react("happy",d.x); backend.playFeedback("hit")
    }
    function finish() {
        if(!running || resultSaved)return
        running=false; paused=false; resultSaved=true; buffer=""
        backend.saveGameScore("letter-rain",score,45-seconds,difficulty,bestCombo,attempts?Math.round(correctChars/attempts*100):100)
    }
    function submitInput(text) {
        if(!running || paused || text.length!==1 || !/[a-z;]/i.test(text))return
        attempts++
        var key=text.toLowerCase(), found=-1, best=-1
        if(config.mode!=="words") {
            for(var i=0;i<drops.length;i++)if(drops[i].token===key && drops[i].y>best){found=i;best=drops[i].y}
            if(found>=0){correctChars++;hitAt(found)}else{combo=0;react("sad",mascotX)}
        } else {
            var candidate=buffer+key, possible=false
            for(var j=0;j<drops.length;j++) {
                if(drops[j].token.indexOf(candidate)===0)possible=true
                if(drops[j].token===candidate && drops[j].y>best){found=j;best=drops[j].y}
            }
            if(possible){correctChars++;buffer=candidate;if(found>=0)hitAt(found)}
            else{buffer="";combo=0;react("sad",mascotX)}
        }
    }
    Keys.onPressed: function(event) {
        if(event.key===Qt.Key_Escape && running){paused=!paused;event.accepted=true;return}
        if(event.key===Qt.Key_Backspace && running){if(!paused)buffer=buffer.slice(0,-1);event.accepted=true;return}
        if(event.text.length===1 && running){submitInput(event.text);event.accepted=true}
    }
    Timer { id:moodTimer; interval:650; onTriggered:game.mood="idle" }
    Timer { interval:config.spawn_ms; running:game.playing; repeat:true; onTriggered:game.spawn() }
    Timer { interval:40; running:game.playing; repeat:true; onTriggered:game.advance() }
    Timer { interval:1000; running:game.playing; repeat:true; onTriggered:{game.seconds--;if(game.seconds<=0)game.finish()} }

    ColumnLayout {
        anchors.fill:parent; spacing:10
        RowLayout {
            Layout.fillWidth:true
            Column {
                Text { text:"字母雨"; color:"#302B47"; font.pixelSize:24; font.bold:true }
                Text { text:game.config.mode==="words"?"把单词变成一场小小的晴天":"看准雨滴，按下同样的字母"; color:"#817B91"; font.pixelSize:12 }
            }
            Item { Layout.fillWidth:true }
            DifficultyPicker { Layout.rightMargin:50; moduleKey:"letter-rain"; onSelectedByUser:function(v){game.difficulty=v;if(game.running)game.reset()} }
        }
        Rectangle {
            Layout.fillWidth:true; Layout.preferredHeight:48; radius:16; color:"#EDF5FF"
            RowLayout {
                anchors.fill:parent; anchors.margins:12; spacing:12
                Image { source:"../resources/games/star.png"; Layout.preferredWidth:26; Layout.preferredHeight:26; fillMode:Image.PreserveAspectFit; smooth:true }
                Text { text:game.score; color:"#4262A4"; font.pixelSize:23; font.bold:true }
                Text { text:game.combo>=2?"连击 ×"+game.combo:"接住每一份小勇气"; color:"#9A7139"; font.pixelSize:13; font.bold:game.combo>=2 }
                Item { Layout.fillWidth:true }
                Repeater { model:Math.max(0,game.lives); Image { source:"../resources/games/heart.png"; Layout.preferredWidth:23; Layout.preferredHeight:25; fillMode:Image.PreserveAspectFit; smooth:true } }
                Text { text:game.seconds+" 秒"; color:game.seconds<10?"#E96C85":"#56718D"; font.pixelSize:17; font.bold:true }
                Rectangle { width:38; height:30; radius:10; color:"#DAE8F8"; visible:game.running
                    Text { anchors.centerIn:parent; text:game.paused?"▶":"Ⅱ"; color:"#4262A4" }
                    MouseArea { anchors.fill:parent; onClicked:{game.paused=!game.paused;game.forceActiveFocus()} }
                }
            }
        }
        Rectangle {
            id:playfield; Layout.fillWidth:true; Layout.fillHeight:true; radius:22; clip:true
            gradient:Gradient { GradientStop{position:0;color:"#BBE3F6"} GradientStop{position:0.65;color:"#E4F4FC"} GradientStop{position:1;color:"#DFEED5"} }
            Repeater { model:7
                Rectangle { required property int index; x:index*playfield.width/6-45; y:18+(index%3)*18; width:100; height:30; radius:20; color:"#FFFFFF"; opacity:0.3 }
            }
            Rectangle { anchors.bottom:parent.bottom; width:parent.width; height:51; color:"#C5DDB7"; radius:20 }
            Rectangle { anchors.bottom:parent.bottom; anchors.bottomMargin:45; width:parent.width; height:1; color:"#A4C59C" }
            Repeater {
                model:game.drops
                Item {
                    required property var modelData
                    width:Math.max(70,dropLabel.implicitWidth+26); height:85
                    x:Math.max(4,Math.min(playfield.width-width-4,modelData.x*playfield.width-width/2)); y:modelData.y
                    Image { anchors.fill:parent; source:"../resources/games/rain-drop.png"; fillMode:Image.PreserveAspectFit; smooth:true }
                    Text { id:dropLabel; anchors.centerIn:parent; anchors.verticalCenterOffset:12; text:modelData.token; color:"#FFFFFF"; font.pixelSize:game.config.mode==="words"?18:27; font.bold:true; style:Text.Outline; styleColor:"#154D9D" }
                    Rectangle { anchors.bottom:parent.bottom; anchors.bottomMargin:3; anchors.horizontalCenter:parent.horizontalCenter; width:dropLabel.width+12; height:3; radius:2; color:"#F8C466"; visible:game.buffer.length>0&&modelData.token.indexOf(game.buffer)===0 }
                }
            }
            Repeater { model:game.splashes
                Text { required property var modelData; x:modelData.x*playfield.width-width/2; y:modelData.y-(game.reducedMotion?0:modelData.age*2); text:"+"+modelData.points; color:"#347F62"; font.pixelSize:23; font.bold:true; opacity:1-modelData.age/15 }
            }
            Image {
                width:156; height:142; anchors.bottom:parent.bottom; anchors.bottomMargin:51
                x:Math.max(0,Math.min(playfield.width-width,game.mascotX*playfield.width-width/2))
                source:"../resources/games/rain-"+game.mood+".png"; fillMode:Image.PreserveAspectFit; smooth:true
                Behavior on x { enabled:!game.reducedMotion; NumberAnimation { duration:200; easing.type:Easing.OutCubic } }
            }
            Rectangle {
                anchors.horizontalCenter:parent.horizontalCenter; anchors.bottom:parent.bottom; anchors.bottomMargin:14
                width:Math.max(170,typingText.implicitWidth+28); height:34; radius:12; color:"#F2FFFFFF"; visible:game.running
                Text { id:typingText; anchors.centerIn:parent; text:game.config.mode==="words"?(game.buffer||"输入完整单词接雨滴"):"按字母接住雨滴"; color:"#3C6583"; font.pixelSize:14; font.bold:true }
            }
            Text { anchors.top:parent.top; anchors.right:parent.right; anchors.margins:14; text:"Esc 暂停 · 退格修改"; color:"#557D96"; font.pixelSize:11; visible:game.running }
            Rectangle {
                anchors.fill:parent; color:game.paused?"#CCEDF7FC":"#E6EAF6FB"; visible:!game.running||game.paused
                Image { anchors.horizontalCenter:parent.horizontalCenter; anchors.top:parent.top; anchors.topMargin:15; width:Math.min(parent.width-40,820); height:Math.min(parent.height-150,width*0.38); source:"../resources/games/rain-cover.png"; fillMode:Image.PreserveAspectFit; smooth:true; visible:!game.paused&&!game.resultSaved
                    MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked:game.start() }
                }
                Column {
                    anchors.horizontalCenter:parent.horizontalCenter
                    y:(!game.resultSaved&&!game.paused)?parent.height-135:(parent.height-height)/2
                    spacing:10
                    Text { anchors.horizontalCenter:parent.horizontalCenter; text:game.paused?"雨滴等你回来":game.resultSaved?(game.lives>0?"接雨任务完成！":"小雨伞需要休息啦"):"和小雨伞一起，接住字母吧"; color:"#34516F"; font.pixelSize:22; font.bold:true }
                    Text { anchors.horizontalCenter:parent.horizontalCenter; text:game.resultSaved?"得分 "+game.score+"  ·  最佳连击 "+game.bestCombo+"  ·  准确率 "+(game.attempts?Math.round(game.correctChars/game.attempts*100):100)+"%":game.paused?"按 Esc 继续，别让小雨滴等太久":"45 秒快乐练习 · 看清楚，再按键"; color:"#6A8397"; font.pixelSize:13 }
                    AppButton { anchors.horizontalCenter:parent.horizontalCenter; text:game.paused?"继续接雨":game.resultSaved?"再玩一次":"开始接雨"; onClicked:{if(game.paused){game.paused=false;game.forceActiveFocus()}else game.start()} }
                }
            }
        }
    }
}
