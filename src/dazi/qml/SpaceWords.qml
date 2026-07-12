import QtQuick
import QtQuick.Layouts

Item {
    id:game
    property string difficulty:"normal"
    property var enemies:[]
    property var sets:({easy:["cat","sun","map","red","book"],normal:["planet","school","window","friend","bright"],hard:["keyboard","accuracy","adventure","challenge","excellent"]})
    property var config:backend.gameConfig["space-words"][difficulty]
    property bool running:false
    property int wave:1
    property int lives:3
    property int score:0
    property int combo:0
    property int bestCombo:0
    property int shots:0
    property int hits:0
    property string buffer:""
    property int elapsed:0
    function reset(){enemies=[];wave=1;lives=config.lives;score=0;combo=0;bestCombo=0;shots=0;hits=0;buffer="";elapsed=0;running=true;forceActiveFocus()}
    function spawn(){var list=sets[difficulty],next=enemies.slice(),boss=wave%5===0;var word=boss?(list[Math.floor(Math.random()*list.length)]+list[Math.floor(Math.random()*list.length)]):list[Math.floor(Math.random()*list.length)];next.push({word:word,x:30+Math.random()*Math.max(80,field.width-150),y:20,boss:boss});enemies=next}
    function advance(){var next=[],miss=0;for(var i=0;i<enemies.length;i++){var e=enemies[i],ny=e.y+config.fall_step;if(ny>field.height-65)miss++;else next.push({word:e.word,x:e.x,y:ny,boss:e.boss})}enemies=next;if(miss){lives-=miss;combo=0}if(lives<=0)finish()}
    function finish(){if(!running)return;running=false;backend.saveGameScore("space-words",score,elapsed,difficulty,bestCombo,shots?Math.round(hits/shots*100):100)}
    Keys.onPressed:function(event){if(!running||event.text.length!==1)return;buffer+=event.text.toLowerCase();shots++;var match=-1,possible=false;for(var i=0;i<enemies.length;i++){if(enemies[i].word===buffer)match=i;if(enemies[i].word.indexOf(buffer)===0)possible=true}if(match>=0){var wasBoss=enemies[match].boss;var next=enemies.slice();next.splice(match,1);enemies=next;hits++;combo++;bestCombo=Math.max(bestCombo,combo);score+=wasBoss?50:15+combo;buffer="";backend.playFeedback("hit");if(hits%6===0)wave++}else if(!possible){buffer="";combo=0}event.accepted=true}
    Timer{interval:config.spawn_ms;running:game.running;repeat:true;onTriggered:game.spawn()}
    Timer{interval:45;running:game.running;repeat:true;onTriggered:game.advance()}
    Timer{interval:1000;running:game.running;repeat:true;onTriggered:game.elapsed++}
    ColumnLayout{anchors.fill:parent;spacing:10
        RowLayout{Layout.fillWidth:true; Column{Text{text:"单词太空战";color:"#302B47";font.pixelSize:24;font.bold:true} Text{text:"输入单词，发射光束保卫星球";color:"#817B91";font.pixelSize:12}} Item{Layout.fillWidth:true} DifficultyPicker{Layout.rightMargin:60;moduleKey:"space-words";onSelectedByUser:function(v){game.difficulty=v;if(game.running)game.reset()}}}
        RowLayout{Layout.fillWidth:true; Text{text:"第 "+game.wave+" 波";color:"#6657E8";font.bold:true} Text{text:"得分 "+game.score+"  连击 ×"+game.combo;color:"#817B91"} Item{Layout.fillWidth:true} Text{text:"♥".repeat(Math.max(0,game.lives));color:"#EF6C93";font.pixelSize:20}}
        Rectangle{id:field;Layout.fillWidth:true;Layout.fillHeight:true;radius:20;color:"#151C3B";clip:true
            Repeater{model:game.enemies; Rectangle{required property var modelData;x:modelData.x;y:modelData.y;width:Math.max(72,enemyText.width+28);height:modelData.boss?58:44;radius:18;color:modelData.boss?"#EF6C93":"#5265C9"; Text{id:enemyText;anchors.centerIn:parent;text:(modelData.boss?"👾 ":"")+modelData.word;color:"white";font.pixelSize:16;font.bold:true}}}
            Text{anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:18;text:"🚀  "+game.buffer;color:"#8DE4FF";font.pixelSize:20;font.bold:true}
            Column{anchors.centerIn:parent;visible:!game.running;spacing:14; Text{anchors.horizontalCenter:parent.horizontalCenter;text:game.score?"任务结束 · "+game.score+" 分":"准备保卫打字星球";color:"white";font.pixelSize:24;font.bold:true} AppButton{anchors.horizontalCenter:parent.horizontalCenter;text:game.score?"再次出发":"开始任务";onClicked:game.reset()}}
        }
    }
}
