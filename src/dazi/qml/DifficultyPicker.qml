import QtQuick
import QtQuick.Layouts

RowLayout {
    id: picker
    property string moduleKey: "course"
    property string selected: "normal"
    signal selectedByUser(string value)
    spacing: 7

    Component.onCompleted: {
        selected = backend.moduleDifficulty(moduleKey)
        selectedByUser(selected)
    }
    Repeater {
        model: [{key:"easy", label:"简单"}, {key:"normal", label:"普通"}, {key:"hard", label:"困难"}]
        delegate: Rectangle {
            required property var modelData
            Layout.preferredWidth: 72; Layout.preferredHeight: 36; radius: 11
            color: picker.selected === modelData.key ? "#6657E8" : "#ECE9F6"
            Text { anchors.centerIn: parent; text: modelData.label; color: picker.selected === modelData.key ? "white" : "#625C72"; font.pixelSize: 13; font.bold: picker.selected === modelData.key }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: {
                picker.selected = modelData.key
                backend.setModuleDifficulty(picker.moduleKey, modelData.key)
                picker.selectedByUser(modelData.key)
            }}
        }
    }
}
