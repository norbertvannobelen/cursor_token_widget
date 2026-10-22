import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: bar

    property real fraction: 0
    property color fillColor: Kirigami.Theme.highlightColor

    implicitHeight: Math.max(4, Kirigami.Units.smallSpacing)
    radius: height / 2
    color: Qt.alpha(Kirigami.Theme.textColor, 0.16)

    Rectangle {
        width: Math.max(0, Math.min(1, bar.fraction)) * parent.width
        height: parent.height
        radius: parent.radius
        color: bar.fillColor
    }
}
