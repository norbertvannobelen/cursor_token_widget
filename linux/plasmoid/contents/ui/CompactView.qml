import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

ColumnLayout {
    id: view

    required property var snapshot
    property string note: ""

    spacing: Kirigami.Units.smallSpacing

    RowLayout {
        Layout.fillWidth: true
        PlasmaComponents.Label {
            text: view.snapshot.signedIn ? "Usage" : "Cursor"
            font.bold: true
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize + 1
            Layout.fillWidth: true
        }
        PlasmaComponents.Label {
            text: view.snapshot.membership || ""
            visible: view.snapshot.signedIn && text.length > 0
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1
            color: Kirigami.Theme.disabledTextColor
        }
    }

    Meter {
        visible: view.snapshot.signedIn
        Layout.fillWidth: true
        title: "Cursor"
        value: view.snapshot.cursor.text
        fraction: view.snapshot.cursor.fraction
        warning: view.snapshot.cursor.warning
        tint: Kirigami.Theme.highlightColor
    }
    Meter {
        visible: view.snapshot.signedIn
        Layout.fillWidth: true
        title: "Other"
        value: view.snapshot.other.text
        fraction: view.snapshot.other.fraction
        warning: view.snapshot.other.warning
        tint: Qt.alpha(Kirigami.Theme.textColor, 0.55)
    }
    Meter {
        visible: view.snapshot.signedIn && view.snapshot.onDemand
        Layout.fillWidth: true
        title: "On-demand"
        value: view.snapshot.onDemand ? view.snapshot.onDemand.pairText : ""
        fraction: view.snapshot.onDemand ? view.snapshot.onDemand.fraction : 0
        warning: view.snapshot.onDemand ? view.snapshot.onDemand.warning : false
        tint: Kirigami.Theme.neutralTextColor
    }

    ColumnLayout {
        visible: view.snapshot.signedIn
        Layout.fillWidth: true
        spacing: 1
        Stat { label: "Today"; value: view.snapshot.tokens.today }
        Stat { label: "7 days"; value: view.snapshot.tokens.week }
        Stat { label: "30 days"; value: view.snapshot.tokens.month }
    }

    PlasmaComponents.Label {
        visible: !view.snapshot.signedIn
        Layout.fillWidth: true
        text: view.note.length > 0 ? view.note : "Right-click and choose Configure Cursor Usage."
        wrapMode: Text.WordWrap
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        color: Kirigami.Theme.disabledTextColor
    }

    Item { Layout.fillHeight: true }
}

component Stat: RowLayout {
    id: stat
    property string label
    property string value
    Layout.fillWidth: true
    PlasmaComponents.Label {
        text: stat.label
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        color: Kirigami.Theme.disabledTextColor
        Layout.fillWidth: true
    }
    PlasmaComponents.Label {
        text: stat.value
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        font.bold: true
        font.family: "monospace"
    }
}
