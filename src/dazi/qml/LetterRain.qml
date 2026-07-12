import QtQuick
import QtQuick.Layouts

Item {
    id: game
    signal closeRequested()
    property var drops: []
    property int score: 0
    property int lives: 3
    property int seconds: 45
    property bool running: false
    property string difficulty: "normal"
    property int combo: 0
    property int bestCombo: 0
    property int attempts: 0
    property int hits: 0
    property string buffer: ""
    property var config: backend.gameConfig["letter-rain"][difficulty]
    property string alphabet: config.mode === "home" ? "asdfjkl;" : "asdfjkl;qwertyuiopzxcvbnm"
    property var words: ["cat","sun","tree","book","green","happy","planet","window","school","friend"]

    function reset() { drops=[]; score=0; lives=config.lives; seconds=45; combo=0; bestCombo=0; attempts=0; hits=0; buffer=""; running=true; forceActiveFocus() }
    function spawn() {
        var next=drops.slice(); var token=config.mode==="words" ? words[Math.floor(Math.random()*words.length)] : alphabet[Math.floor(Math.random()*alphabet.length)]
        next.push({token:token, x:30+Math.random()*Math.max(80,playfield.width-120), y:18}); drops=next
    }
    function advance() {
        var next=[], missed=0
        for (var i=0;i<drops.length;i++) { var d=drops[i], ny=d.y+config.fall_step+score/80; if(ny>playfield.height-54) missed++; else next.push({token:d.token,x:d.x,y:ny}) }
        drops=next
        if(missed) { lives-=missed; combo=0 }
        if(lives<=0) finish()
    }
    function hitAt(index) { var next=drops.slice(); next.splice(index,1); drops=next; hits++; combo++; bestCombo=Math.max(bestCombo,combo); score+=10+Math.min(20,combo*2); buffer=""; backend.playFeedback("hit") }
    function finish() { if(!running)return; running=false; backend.saveGameScore("letter-rain",score,45-seconds,difficulty,bestCombo,attempts?Math.round(hits/attempts*100):100) }
    Keys.onPressed: function(event) {
        if(!running || event.text.length!==1)return
        attempts++
        if(config.mode!=="words") {
            var key=event.text.toLowerCase(), found=-1, best=-1
            for(var i=0;i<drops.length;i++) if(drops[i].token===key && drops[i].y>best){found=i;best=drops[i].y}
            if(found>=0) hitAt(found); else combo=0
        } else {
            buffer+=event.text.toLowerCase(); var match=-1, possible=false
            for(var j=0;j<drops.length;j++){ if(drops[j].token===buffer)match=j; if(drops[j].token.indexOf(buffer)===0)possible=true }
            if(match>=0)hitAt(match); else if(!possible){buffer="";combo=0}
        }
        event.accepted=true
    }
    Timer { interval:config.spawn_ms; running:game.running; repeat:true; onTriggered:game.spawn() }
    Timer { interval:40; running:game.running; repeat:true; onTriggered:game.advance() }
    Timer { interval:1000; running:game.running; repeat:true; onTriggered:{game.seconds--;if(game.seconds<=0)game.finish()} }

    ColumnLayout { anchors.fill:parent; spacing:10
        RowLayout { Layout.fillWidth:true
            Column { Text{text:"字母雨";color:"#302B47";font.pixelSize:24;font.bold:true} Text{text:game.config.mode==="words"?"输入完整单词接住它":"按下正在坠落的字母";color:"#817B91";font.pixelSize:12} }
            Item{Layout.fillWidth:true} DifficultyPicker{Layout.rightMargin:60;moduleKey:"letter-rain";onSelectedByUser:function(v){game.difficulty=v;if(game.running)game.reset()}}
        }
        RowLayout { Layout.fillWidth:true
            Text{text:"得分  "+game.score;color:"#6657E8";font.pixelSize:17;font.bold:true} Text{text:"连击 ×"+game.combo;color:"#F2A93B";font.bold:true}
            Item{Layout.fillWidth:true} Text{text:"♥".repeat(Math.max(0,game.lives));color:"#EF6C93";font.pixelSize:20} Text{text:game.seconds+" 秒";color:"#817B91"}
        }
        Rectangle { id:playfield;Layout.fillWidth:true;Layout.fillHeight:true;radius:20;color:"#292541";clip:true
            Repeater { model:game.drops
                Rectangle { required property var modelData; x:modelData.x;y:modelData.y;width:Math.max(48,tokenText.width+22);height:44;radius:14;color:"#7769EF"
                    Text{id:tokenText;anchors.centerIn:parent;text:modelData.token.toUpperCase();color:"white";font.pixelSize:18;font.bold:true}
                }
            }
            Text { visible:game.config.mode==="words"&&game.running;anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:15;text:"正在输入："+game.buffer;color:"#DAD5FF";font.pixelSize:16 }
            Column { anchors.centerIn:parent;visible:!game.running;spacing:14
                Text{anchors.horizontalCenter:parent.horizontalCenter;text:game.score?"本局 "+game.score+" 分 · 最高 "+game.bestCombo+" 连击":"准备接住字母了吗？";color:"white";font.pixelSize:23;font.bold:true}
                AppButton{anchors.horizontalCenter:parent.horizontalCenter;text:game.score?"再玩一次":"开始";onClicked:game.reset()}
            }
        }
    }
}
