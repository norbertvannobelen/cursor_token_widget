import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

ColumnLayout {
    id: meter

    property string title
    property string value
    property real fraction: 0
    property bool warning: false
    property color tint: Kirigami.Theme.highlightColor
    property int valuePixelSize: Kirigami.Theme.smallFont.pixelSize

    spacing: 2

    RowLayout {
        Layout.fillWidth: true
        PlasmaComponents.Label {
            text: meter.title
            font.pixelSize: meter.valuePixelSize
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        PlasmaComponents.Label {
            text: meter.value
            font.pixelSize: meter.valuePixelSize
            font.bold: true
            font.family: "monospace"
        }
    }

    Bar {
        Layout.fillWidth: true
        fraction: meter.fraction
        fillColor: meter.warning ? Kirigami.Theme.negativeTextColor : meter.tint
    }

    Accessible.name: meter.title + " " + meter.value
    Accessible.role: Accessible.StaticText
}
