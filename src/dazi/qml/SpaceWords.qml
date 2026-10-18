import QtQuick
import QtQuick.Layouts

Item {
    id:game
    objectName:"spaceWordsGame"
    signal closeRequested()
    property string difficulty:"normal"
    property var enemies:[]
    property var sets:({easy:["cat","sun","map","red","book"],normal:["planet","school","window","friend","bright"],hard:["keyboard","accuracy","adventure","challenge","excellent"]})
    property var config:backend.gameConfig["space-words"][difficulty]
    property bool running:false
    property bool paused:false
    property bool onScreen:true
    readonly property bool playing:running&&!paused&&visible&&onScreen
    property bool resultSaved:false
    property string gameState:running?(paused?"paused":"playing"):(resultSaved?"finished":"ready")
    property int wave:1
    property int lives:3
    property int score:0
    property int combo:0
    property int bestCombo:0
    property int shots:0
    property int hits:0
    property int correctChars:0
    readonly property int accuracy:shots?Math.round(correctChars/shots*100):100
    property string buffer:""
    property int elapsed:0
    property int nextId:0
    property var impacts:[]
    property real targetX:0.5
    property bool firing:false
    property bool damaged:false
    readonly property bool reducedMotion:backend.reducedMotion
    function start(){reset()}
    function reset(){
        enemies=[];impacts=[];nextId=0;wave=1;lives=config.lives;score=0;combo=0;bestCombo=0
        shots=0;hits=0;correctChars=0;buffer="";elapsed=0;targetX=0.5;firing=false;damaged=false
        fireTimer.stop();damageTimer.stop();paused=false;resultSaved=false;running=true;spawn();forceActiveFocus()
    }
    function spawn(){
        if(!running||paused)return
        var list=sets[config.word_set||difficulty], next=enemies.slice(), boss=wave%5===0 && !enemies.some(function(e){return e.boss})
        var word=boss?(list[Math.floor(Math.random()*list.length)]+list[Math.floor(Math.random()*list.length)]):list[Math.floor(Math.random()*list.length)]
        next.push({id:nextId++,word:word,x:0.13+Math.random()*0.74,y:-35,boss:boss,kind:Math.floor(Math.random()*5)})
        enemies=next
    }
    function advance(){
        if(!running||paused)return
        var next=[],miss=0
        for(var i=0;i<enemies.length;i++){
            var e=enemies[i],ny=e.y+config.fall_step
            if(ny>field.height-115)miss++
            else next.push({id:e.id,word:e.word,x:e.x,y:ny,boss:e.boss,kind:e.kind})
        }
        enemies=next
        var fx=[];for(var j=0;j<impacts.length;j++){var p=impacts[j];if(p.age<12)fx.push({x:p.x,y:p.y,age:p.age+1,boss:p.boss})}impacts=fx
        if(miss){lives=Math.max(0,lives-miss);combo=0;buffer="";damaged=true;damageTimer.restart()}
        if(lives<=0)finish()
    }
    function finish(){
        if(!running||resultSaved)return
        running=false;paused=false;resultSaved=true;buffer="";firing=false
        backend.saveGameScore("space-words",score,elapsed,difficulty,bestCombo,accuracy)
    }
    function hitAt(index){
        if(!running||paused||index<0||index>=enemies.length)return
        var enemy=enemies[index],next=enemies.slice();next.splice(index,1);enemies=next
        var fx=impacts.slice();fx.push({x:enemy.x,y:enemy.y,age:0,boss:enemy.boss});impacts=fx
        hits++;combo++;bestCombo=Math.max(bestCombo,combo);score+=enemy.boss?50:15+combo
        buffer="";backend.playFeedback("hit");if(hits%6===0)wave++
        if(wave>5)finish()
    }
    function submitInput(text){
        if(!running||paused||text.length!==1||!/[a-z]/i.test(text))return
        shots++
        var candidate=buffer+text.toLowerCase(),match=-1,target=-1,best=-1
        for(var i=0;i<enemies.length;i++){
            if(enemies[i].word.indexOf(candidate)===0 && enemies[i].y>best){target=i;best=enemies[i].y}
            if(enemies[i].word===candidate)match=i
        }
        if(target>=0){
            correctChars++;buffer=candidate;targetX=enemies[target].x;firing=true;fireTimer.restart()
            if(match>=0)hitAt(match)
        }else{buffer="";combo=0}
    }
    Keys.onPressed:function(event){
        if(event.key===Qt.Key_Escape&&running){paused=!paused;event.accepted=true;return}
        if(event.key===Qt.Key_Backspace&&running){if(!paused)buffer=buffer.slice(0,-1);event.accepted=true;return}
        if(event.text.length===1&&running){submitInput(event.text);event.accepted=true}
    }
    Timer{id:fireTimer;interval:180;onTriggered:game.firing=false}
    Timer{id:damageTimer;interval:500;onTriggered:game.damaged=false}
    Timer{interval:config.spawn_ms;running:game.playing;repeat:true;onTriggered:game.spawn()}
    Timer{interval:45;running:game.playing;repeat:true;onTriggered:game.advance()}
    Timer{interval:1000;running:game.playing;repeat:true;onTriggered:game.elapsed++}
    ColumnLayout {
        anchors.fill:parent;spacing:10
        RowLayout {
            Layout.fillWidth:true
            Column {
                Text{text:"单词太空战";color:"#302B47";font.pixelSize:24;font.bold:true}
                Text{text:"输入单词发射光束，完成 5 波星际任务";color:"#817B91";font.pixelSize:12}
            }
            Item{Layout.fillWidth:true}
            DifficultyPicker{Layout.rightMargin:50;moduleKey:"space-words";onSelectedByUser:function(v){game.difficulty=v;if(game.running)game.reset()}}
        }
        Rectangle {
            Layout.fillWidth:true;Layout.preferredHeight:48;radius:16;color:"#ECECFA"
            RowLayout {
                anchors.fill:parent;anchors.margins:12;spacing:12
                Image{source:"../resources/games/star.png";Layout.preferredWidth:26;Layout.preferredHeight:26;fillMode:Image.PreserveAspectFit;smooth:true}
                Text{text:game.score;color:"#5B4BA2";font.pixelSize:23;font.bold:true}
                Text{text:"第 "+Math.min(5,game.wave)+" / 5 波";color:"#6D62A4";font.pixelSize:14;font.bold:true}
                Text{text:game.combo>=2?"连击 ×"+game.combo:"";color:"#AF7C30";font.pixelSize:13;font.bold:true}
                Item{Layout.fillWidth:true}
                Text{text:game.accuracy+"%";color:"#6D62A4";font.pixelSize:14}
                Repeater{model:Math.max(0,game.lives);Image{source:"../resources/games/heart.png";Layout.preferredWidth:22;Layout.preferredHeight:24;fillMode:Image.PreserveAspectFit;smooth:true}}
                Rectangle{width:38;height:30;radius:10;color:"#DDDAF2";visible:game.running
                    Text{anchors.centerIn:parent;text:game.paused?"▶":"Ⅱ";color:"#5B4BA2"}
                    MouseArea{anchors.fill:parent;onClicked:{game.paused=!game.paused;game.forceActiveFocus()}}
                }
            }
        }
        Rectangle {
            id:field;Layout.fillWidth:true;Layout.fillHeight:true;radius:22;clip:true
            gradient:Gradient{GradientStop{position:0;color:"#131D42"}GradientStop{position:0.65;color:"#283667"}GradientStop{position:1;color:"#4C407E"}}
            Image{width:200;height:180;x:parent.width*0.48;y:32;source:"../resources/games/space-nebula.png";opacity:0.2;fillMode:Image.PreserveAspectFit;smooth:true}
            Repeater{model:42
                Rectangle{required property int index;width:index%5===0?3:2;height:width;radius:width/2;color:index%3===0?"#C7C4FF":"#FFFFFF";opacity:0.25+(index%5)*0.13;x:((index*137+27)%997)/997*field.width;y:((index*71+19)%421)/421*field.height}
            }
            Image{width:100;height:100;x:20;y:40;source:"../resources/games/space-saturn.png";opacity:0.55;fillMode:Image.PreserveAspectFit;smooth:true}
            Image{width:180;height:180;x:parent.width-115;y:parent.height-130;source:"../resources/games/space-earth.png";opacity:0.8;fillMode:Image.PreserveAspectFit;smooth:true}
            Image{width:45;height:70;x:parent.width*0.78;y:28;rotation:25;source:"../resources/games/space-meteor.png";opacity:0.4;fillMode:Image.PreserveAspectFit;smooth:true}
            Text{anchors.top:parent.top;anchors.right:parent.right;anchors.margins:14;text:"Esc 暂停 · 退格修改";color:"#B8C8EB";font.pixelSize:11;visible:game.running}
            Rectangle{anchors.bottom:parent.bottom;anchors.bottomMargin:95;width:parent.width;height:1;color:game.damaged?"#FF7A9A":"#6B8CB9";opacity:0.5}
            Repeater {
                model:game.enemies
                Item {
                    required property var modelData
                    width:Math.max(modelData.boss?135:92,wordText.implicitWidth+24);height:modelData.boss?100:83
                    x:Math.max(5,Math.min(field.width-width-5,modelData.x*field.width-width/2));y:modelData.y
                    Image {
                        anchors.horizontalCenter:parent.horizontalCenter;anchors.top:parent.top;width:modelData.boss?118:74;height:modelData.boss?76:59
                        source:"../resources/games/"+(modelData.boss?"space-boss":["space-enemy-green","space-enemy-red","space-enemy-yellow","space-enemy-purple","space-enemy-robot"][modelData.kind])+".png"
                        fillMode:Image.PreserveAspectFit;smooth:true
                    }
                    Rectangle {
                        anchors.bottom:parent.bottom;width:parent.width;height:28;radius:10
                        color:game.buffer.length>0&&modelData.word.indexOf(game.buffer)===0?"#355B79":"#CC16213F"
                        border.width:1;border.color:game.buffer.length>0&&modelData.word.indexOf(game.buffer)===0?"#82E4EE":"#6375A3"
                        Text{id:wordText;anchors.centerIn:parent;text:modelData.word;color:"#FFFFFF";font.pixelSize:16;font.bold:true}
                        Rectangle{anchors.left:parent.left;anchors.bottom:parent.bottom;anchors.leftMargin:8;width:(parent.width-16)*(game.buffer.length/modelData.word.length);height:2;radius:1;color:"#8EF2E5";visible:game.buffer.length>0&&modelData.word.indexOf(game.buffer)===0}
                    }
                }
            }
            Repeater {
                model:game.impacts
                Item {
                    required property var modelData
                    x:modelData.x*field.width-45;y:modelData.y;width:90;height:90;opacity:1-modelData.age/13
                    Image{anchors.fill:parent;source:"../resources/games/space-bolt.png";fillMode:Image.PreserveAspectFit;smooth:true;scale:game.reducedMotion?1:0.7+modelData.age/10}
                    Text{anchors.centerIn:parent;text:modelData.boss?"+50":"命中！";color:"#FFF1AF";font.pixelSize:19;font.bold:true}
                }
            }
            Rectangle {
                visible:game.firing&&!game.paused&&!game.reducedMotion
                x:player.x+player.width/2-2;y:30;width:4;height:Math.max(0,player.y-20);radius:2;color:"#9AF9FF";opacity:0.5
            }
            Image {
                id:player;width:132;height:100;rotation:-90;anchors.bottom:parent.bottom;anchors.bottomMargin:45
                x:Math.max(0,Math.min(field.width-width,game.targetX*field.width-width/2))
                source:"../resources/games/"+(game.firing&&!game.paused?"space-player-fire":"space-player")+".png";fillMode:Image.PreserveAspectFit;smooth:true
                Behavior on x{enabled:!game.reducedMotion;NumberAnimation{duration:180;easing.type:Easing.OutCubic}}
            }
            Image{width:125;height:125;x:player.x-14;y:player.y-16;source:"../resources/games/space-shield.png";fillMode:Image.PreserveAspectFit;smooth:true;visible:game.damaged}
            Rectangle {
                anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:9
                width:Math.max(220,inputText.implicitWidth+30);height:30;radius:10;color:"#D11A2448";border.color:"#6575A3";visible:game.running
                Text{id:inputText;anchors.centerIn:parent;text:game.buffer||"输入上方单词，发射！";color:game.buffer?"#A6FAEE":"#C3CDEE";font.pixelSize:16;font.bold:true}
            }
            Rectangle {
                anchors.fill:parent;color:game.paused?"#DB152144":"#E6162145";visible:!game.running||game.paused
                Image{anchors.horizontalCenter:parent.horizontalCenter;anchors.top:parent.top;anchors.topMargin:15;width:Math.min(parent.width-40,820);height:Math.min(parent.height-150,width*0.35);source:"../resources/games/space-cover.png";fillMode:Image.PreserveAspectFit;smooth:true;visible:!game.resultSaved&&!game.paused
                    MouseArea{anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:game.start()}
                }
                Column {
                    anchors.horizontalCenter:parent.horizontalCenter;y:(!game.resultSaved&&!game.paused)?parent.height-135:(parent.height-height)/2;spacing:10
                    Text{anchors.horizontalCenter:parent.horizontalCenter;text:game.paused?"星际航行已暂停":game.resultSaved?(game.wave>5?"任务完成，星球安全啦！":"飞船返航，勇气满分！"):"小小打字员，准备出发";color:"#F1F3FF";font.pixelSize:22;font.bold:true}
                    Text{anchors.horizontalCenter:parent.horizontalCenter;text:game.resultSaved?"得分 "+game.score+"  ·  准确率 "+game.accuracy+"%  ·  最佳连击 "+game.bestCombo:game.paused?"按 Esc 继续你的太空冒险":"看清单词 · 连续输入 · 保卫星球";color:"#BAC7E7";font.pixelSize:13}
                    AppButton{anchors.horizontalCenter:parent.horizontalCenter;text:game.paused?"继续航行":game.resultSaved?"再次出发":"开始任务";onClicked:{if(game.paused){game.paused=false;game.forceActiveFocus()}else game.start()}}
                }
            }
        }
    }
}
