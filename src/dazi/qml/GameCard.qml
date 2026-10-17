import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: card
    property string emoji
    property string title
    property string description
    property color gradientA
    property color gradientB
    signal play()
    radius: 28
    gradient: Gradient { GradientStop { position: 0; color: card.gradientA } GradientStop { position: 1; color: card.gradientB } }
    ColumnLayout { anchors.fill: parent; anchors.margins: 15; spacing: 6
        Item { Layout.fillHeight: true }
        Text { Layout.alignment: Qt.AlignHCenter; text: card.emoji; font.pixelSize: Math.min(59, card.height * 0.23) }
        Text { Layout.alignment: Qt.AlignHCenter; text: card.title; color: "white"; font.pixelSize: 21; font.bold: true }
        Text { Layout.fillWidth: true; text: card.description; color: "#EEECFF"; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 12; maximumLineCount: 2; elide: Text.ElideRight }
        AppButton { Layout.alignment: Qt.AlignHCenter; text: "开始游戏"; fillColor: "white"; textColor: card.gradientA; onClicked: card.play() }
        Item { Layout.fillHeight: true }
    }
}
