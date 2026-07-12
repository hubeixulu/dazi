import QtQuick
import QtQuick.Layouts

Item {
    id: board
    property string targetText: ""
    property int typedLength: 0
    property bool showHands: true
    property string difficulty: "normal"
    readonly property real keyboardScale: Math.min(1, Math.max(0.58, width / 840))
    readonly property string nextChar: typedLength < targetText.length ? targetText[typedLength] : ""
    readonly property string shifted: "~!@#$%^&*()_+{}|:\"<>?"
    readonly property var rows: [
        ["`","1","2","3","4","5","6","7","8","9","0","-","=","Backspace"],
        ["Tab","q","w","e","r","t","y","u","i","o","p","[","]","\\"],
        ["Caps","a","s","d","f","g","h","j","k","l",";","'","Enter"],
        ["Shift","z","x","c","v","b","n","m",",",".","/","Shift"],
        ["Ctrl","Alt","Space","Alt","Ctrl"]
    ]
    readonly property var shiftMap: ({"~":"`","!":"1","@":"2","#":"3","$":"4","%":"5","^":"6","&":"7","*":"8","(":"9",")":"0","_":"-","+":"=","{":"[","}":"]","|":"\\",":":";","\"":"'","<":",",">":".","?":"/"})

    function baseKey(c) { return shiftMap[c] || c.toLowerCase() }
    function needsShift(c) { return shifted.indexOf(c) >= 0 || (c >= "A" && c <= "Z") }
    function finger(key) {
        key = key.toLowerCase()
        if ("`1qaz".indexOf(key)>=0) return 0
        if ("2wsx".indexOf(key)>=0) return 1
        if ("3edc".indexOf(key)>=0) return 2
        if ("45rtfgvb".indexOf(key)>=0) return 3
        if ("67yuhjnm".indexOf(key)>=0) return 4
        if ("8ik,".indexOf(key)>=0) return 5
        if ("9ol.".indexOf(key)>=0) return 6
        return 7
    }
    function fingerColor(key) { return ["#EF7896","#F2A65A","#E8C447","#64C49B","#5FB7D3","#7B9EEB","#9A83E8","#D77AC7"][finger(key)] }
    function keyWidth(label) { if (label==="Space") return 260; if (label==="Backspace") return 100; if (label==="Shift") return 112; if (label==="Enter" || label==="Caps") return 94; if (label==="Tab") return 76; return label.length>1 ? 64 : 50 }

    implicitHeight: keyboardBody.implicitHeight * keyboardScale
    ColumnLayout {
        id: keyboardBody
        width: 840
        x: Math.max(0, (board.width - width * board.keyboardScale) / 2)
        scale: board.keyboardScale
        transformOrigin: Item.TopLeft
        spacing: 5
        Repeater { model: board.rows
            delegate: RowLayout {
                required property var modelData
                Layout.alignment: Qt.AlignHCenter; spacing: 5
                Repeater { model: parent.modelData
                    delegate: Rectangle {
                        required property string modelData
                        Layout.preferredWidth: board.keyWidth(modelData); Layout.preferredHeight: 46; radius: 9
                        property bool target: board.baseKey(board.nextChar) === modelData.toLowerCase() ||
                                              (modelData === "Space" && board.nextChar === " ") ||
                                              (modelData === "Enter" && board.nextChar === "\n") ||
                                              (modelData === "Shift" && board.needsShift(board.nextChar))
                        color: target ? "#5E50DD" : modelData.length === 1 ? board.fingerColor(modelData) + "55" : "#E8E5F1"
                        border.width: target ? 3 : 1; border.color: target ? "#BEB6FF" : "#D5D0E2"
                        scale: target ? 1.08 : 1
                        Behavior on scale { NumberAnimation { duration: 130 } }
                        Text { anchors.centerIn: parent; text: modelData === "Space" ? "空格" : modelData.toUpperCase(); color: parent.target ? "white" : "#464054"; font.pixelSize: modelData.length>1 ? 10 : 15; font.bold: true }
                    }
                }
            }
        }
        RowLayout { visible: board.showHands; Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 4; spacing: 42
            Repeater { model: [{hand:"左手", labels:["小","无","中","食"]}, {hand:"右手", labels:["食","中","无","小"]}]
                delegate: RowLayout { id: handRow; required property var modelData; spacing: 5
                    Text { text: handRow.modelData.hand; color:"#777189"; font.pixelSize:11 }
                    Repeater { model: handRow.modelData.labels
                        Rectangle { required property string modelData; required property int index; width:34; height:34; radius:17
                            property int handOffset: index + (handRow.modelData.hand === "右手" ? 4 : 0)
                            color: handOffset === board.finger(board.baseKey(board.nextChar)) ? "#5E50DD" : "#E9E6F3"
                            Text { anchors.centerIn:parent; text:modelData; color:parent.color==="#5E50DD"?"white":"#777189"; font.pixelSize:9 }
                        }
                    }
                }
            }
        }
    }
}
