import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: card
    property string emoji
    property string title
    property string description
    property url artwork
    property color gradientA: "#3068BC"
    property color gradientB: "#42B1A2"
    signal play()
    radius: 22
    color: "white"
    border.width: 1
    border.color: artworkMouse.containsMouse ? card.gradientA : "#E4E8F2"
    clip: true

    Image {
        id: cover
        anchors.top: parent.top; anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 16
        height: Math.max(76, card.height - 108)
        source: card.artwork
        fillMode: Image.PreserveAspectCrop
        smooth: true
        MouseArea {
            id: artworkMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.play()
        }
    }
    ColumnLayout {
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: cover.bottom; anchors.bottom: parent.bottom
        anchors.margins: 12; spacing: 5
        RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: card.title; color: "#243A5A"; font.pixelSize: 20; font.bold: true }
            AppButton { implicitWidth: 94; implicitHeight: 34; text: "去冒险  ›"; font.pixelSize: 12; fillColor: card.gradientA; onClicked: card.play() }
        }
        Text { Layout.fillWidth: true; text: card.description; color: "#7B889E"; wrapMode: Text.Wrap; font.pixelSize: 11; maximumLineCount: 2; elide: Text.ElideRight }
        Item { Layout.fillHeight: true }
    }
}
