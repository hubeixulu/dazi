import QtQuick
import QtQuick.Controls

Button {
    id: control
    property color fillColor: "#6657E8"
    property color textColor: "white"
    implicitHeight: 46
    implicitWidth: 128
    font.pixelSize: 15
    font.weight: Font.DemiBold
    contentItem: Text {
        text: control.text
        color: control.textColor
        font: control.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: 14
        color: control.down ? Qt.darker(control.fillColor, 1.12) : control.hovered ? Qt.lighter(control.fillColor, 1.08) : control.fillColor
        Behavior on color { ColorAnimation { duration: 120 } }
    }
}

