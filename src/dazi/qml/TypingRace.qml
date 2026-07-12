import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id:game
    signal closeRequested()
    property string difficulty:"normal"
    property var sets: ({easy:["A sunny day.","Keep a steady rhythm.","Small steps help."],normal:["Small steps make big progress.","Practice makes progress, one key at a time.","The stars shine brightly above us."],hard:["At 8:30, the careful pilot checked every signal before take-off.","Accuracy, patience, and rhythm—these three skills create lasting speed."]})
    property string target:""
    property bool running:false
    property bool finished:false
    property int elapsed:0
    property real opponentProgress:0
    property int combo:0
    property int bestCombo:0
    property int errors:0
    property var config:backend.gameConfig["typing-race"][difficulty]
    function reset(){var list=sets[difficulty];target=list[Math.floor(Math.random()*list.length)];raceInput.text="";running=true;finished=false;elapsed=0;opponentProgress=0;combo=0;bestCombo=0;errors=0;raceInput.forceActiveFocus()}
    function complete(){running=false;finished=true;var accuracy=Math.round(target.length/(target.length+errors)*100);backend.saveGameScore("typing-race",Math.max(10,120-elapsed*2+bestCombo),elapsed,difficulty,bestCombo,accuracy)}
    Timer{interval:200;repeat:true;running:game.running;onTriggered:{game.opponentProgress+=game.config.opponent_speed/100;if(game.opponentProgress>=1){game.running=false;game.finished=true}}}
    Timer{interval:1000;repeat:true;running:game.running;onTriggered:game.elapsed++}
    ColumnLayout {anchors.fill:parent;spacing:12
        RowLayout{Layout.fillWidth:true; Column{Text{text:"打字竞速";color:"#302B47";font.pixelSize:24;font.bold:true} Text{text:"准确输入，让飞船超过电脑对手";color:"#817B91";font.pixelSize:12}} Item{Layout.fillWidth:true} DifficultyPicker{Layout.rightMargin:60;moduleKey:"typing-race";onSelectedByUser:function(v){game.difficulty=v;if(game.running)game.reset()}}}
        Rectangle{Layout.fillWidth:true;Layout.preferredHeight:150;radius:20;color:"#E9F8F3"
            Rectangle{x:25;y:66;width:parent.width-50;height:4;color:"#B8E5D7"} Rectangle{x:25;y:121;width:parent.width-50;height:4;color:"#D8D4E7"}
            Text{text:"🚀";font.pixelSize:38;y:30;x:20+(parent.width-85)*Math.min(1,raceInput.text.length/Math.max(1,game.target.length));Behavior on x{NumberAnimation{duration:160}}}
            Text{text:"🛸";font.pixelSize:34;y:87;x:20+(parent.width-85)*Math.min(1,game.opponentProgress);Behavior on x{NumberAnimation{duration:180}}}
            Text{anchors.right:parent.right;anchors.rightMargin:14;y:41;text:"🏁";font.pixelSize:34}
        }
        Panel{Layout.fillWidth:true;Layout.preferredHeight:92; Text{anchors.centerIn:parent;width:parent.width-40;text:game.target||"选择难度后开始比赛";color:"#302B47";font.pixelSize:20;font.family:"Menlo";wrapMode:Text.Wrap;horizontalAlignment:Text.AlignHCenter}}
        TextField{id:raceInput;Layout.fillWidth:true;Layout.preferredHeight:58;enabled:game.running;placeholderText:"Start typing…";font.pixelSize:19
            property bool valid:game.target.slice(0,text.length)===text
            background:Rectangle{radius:15;color:"white";border.width:2;border.color:raceInput.valid?"#4BC4A2":"#EF6C93"}
            onTextEdited:{if(valid){game.combo++;game.bestCombo=Math.max(game.bestCombo,game.combo)}else{game.errors++;game.combo=0} if(text===game.target)game.complete()}
        }
        RowLayout{Layout.fillWidth:true; Text{text:"用时 "+game.elapsed+" 秒  ·  连击 ×"+game.combo;color:"#817B91"} Item{Layout.fillWidth:true} Text{visible:game.finished;text:raceInput.text===game.target?"你赢了！✨":"电脑先到终点，再试一次！";color:"#20A989";font.bold:true} AppButton{text:game.finished?"再来一局":game.running?"重新开始":"开始竞速";fillColor:"#27B99A";onClicked:game.reset()}}
    }
}
