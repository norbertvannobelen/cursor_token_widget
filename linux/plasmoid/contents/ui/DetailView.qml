import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

ColumnLayout {
    id: view

    required property var snapshot
    spacing: Kirigami.Units.largeSpacing

    RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            PlasmaComponents.Label {
                text: "Cursor Tokens"
                font.bold: true
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize + 4
            }
            PlasmaComponents.Label {
                visible: subtitle.length > 0
                text: subtitle
                color: Kirigami.Theme.disabledTextColor
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    PlasmaComponents.Label {
        visible: !view.snapshot.signedIn
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: "Right-click the widget and choose Configure Cursor Usage. You can use the Cursor account on this computer, or paste a session token."
    }

    Section {
        visible: view.snapshot.signedIn
        title: "Included"
        Meter {
            Layout.fillWidth: true
            title: "Cursor Models"
            value: view.snapshot.cursor.text
            fraction: view.snapshot.cursor.fraction
            warning: view.snapshot.cursor.warning
            tint: Kirigami.Theme.highlightColor
            valuePixelSize: Kirigami.Theme.defaultFont.pixelSize
        }
        Meter {
            Layout.fillWidth: true
            title: "Other Models"
            value: view.snapshot.other.text
            fraction: view.snapshot.other.fraction
            warning: view.snapshot.other.warning
            tint: Qt.alpha(Kirigami.Theme.textColor, 0.55)
            valuePixelSize: Kirigami.Theme.defaultFont.pixelSize
        }
    }

    Section {
        visible: view.snapshot.signedIn && view.snapshot.onDemand
        title: "On-demand"
        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents.Label { text: "Usage"; Layout.fillWidth: true }
            PlasmaComponents.Label {
                text: view.snapshot.onDemand ? view.snapshot.onDemand.usageText : ""
                font.bold: true
                font.family: "monospace"
            }
        }
        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents.Label { text: "Spend limit"; Layout.fillWidth: true }
            PlasmaComponents.Label {
                text: view.snapshot.onDemand ? view.snapshot.onDemand.limitText : ""
                font.bold: true
                font.family: "monospace"
            }
        }
        Bar {
            Layout.fillWidth: true
            implicitHeight: 8
            fraction: view.snapshot.onDemand ? view.snapshot.onDemand.fraction : 0
            fillColor: (view.snapshot.onDemand && view.snapshot.onDemand.warning)
                       ? Kirigami.Theme.negativeTextColor
                       : Kirigami.Theme.neutralTextColor
        }
    }

    Section {
        visible: view.snapshot.signedIn
        title: "Tokens"
        RowLayout {
            Layout.fillWidth: true
            Token { label: "Today"; value: view.snapshot.tokens.today }
            Token { label: "7 days"; value: view.snapshot.tokens.week }
            Token { label: "30 days"; value: view.snapshot.tokens.month }
        }
    }

    PlasmaComponents.Label {
        visible: view.snapshot.error
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: view.snapshot.error || ""
        color: Kirigami.Theme.neutralTextColor
    }

    PlasmaComponents.Label {
        visible: view.snapshot.signedIn
        text: view.snapshot.updatedText ? ("Updated " + view.snapshot.updatedText + " · refreshes every 5 minutes") : ""
        color: Kirigami.Theme.disabledTextColor
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
    }

    Item { Layout.fillHeight: true }

    readonly property string subtitle: {
        var parts = []
        if (view.snapshot.email)
            parts.push(view.snapshot.email)
        if (view.snapshot.membership)
            parts.push(view.snapshot.membership)
        return parts.join(" · ")
    }
}

component Section: ColumnLayout {
    id: section
    property string title
    Layout.fillWidth: true
    spacing: Kirigami.Units.smallSpacing
    PlasmaComponents.Label {
        text: section.title
        color: Kirigami.Theme.disabledTextColor
    }
}

component Token: ColumnLayout {
    id: token
    property string label
    property string value
    Layout.fillWidth: true
    spacing: 0
    PlasmaComponents.Label {
        text: token.label
        color: Kirigami.Theme.disabledTextColor
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
    }
    PlasmaComponents.Label {
        text: token.value
        font.bold: true
        font.family: "monospace"
    }
}
