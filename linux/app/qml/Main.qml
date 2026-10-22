import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.tx.cursortokens 1.0

Kirigami.ApplicationWindow {
    id: window

    title: "Cursor Tokens"
    width: 440
    height: 700
    minimumWidth: 400
    minimumHeight: 560

    property var snapshot: JSON.parse(Backend.snapshotJson)

    Connections {
        target: Backend
        function onSnapshotChanged() {
            window.snapshot = JSON.parse(Backend.snapshotJson)
        }
    }

    Component.onCompleted: {
        Backend.showSnapshot()
        Backend.refresh()
    }

    Timer {
        interval: 5 * 60 * 1000
        repeat: true
        running: true
        onTriggered: Backend.refresh()
    }

    pageStack.initialPage: Kirigami.ScrollablePage {
        title: "Cursor Tokens"

        ColumnLayout {
            width: parent.width
            spacing: Kirigami.Units.largeSpacing

            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true
                QQC2.Label {
                    text: subtitle
                    visible: subtitle.length > 0
                    color: Kirigami.Theme.disabledTextColor
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            ColumnLayout {
                visible: !window.snapshot.signedIn
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: "Sign in once. The desktop widget and this window then show the same allowance bars, on-demand spend, and token totals as the Cursor dashboard."
                }
                QQC2.Button {
                    text: "Use the account signed in to Cursor"
                    onClicked: Backend.signInLocal()
                }
                QQC2.Button {
                    text: "Open cursor.com to copy a token"
                    onClicked: Qt.openUrlExternally("https://cursor.com/dashboard")
                }
                QQC2.TextField {
                    id: tokenField
                    echoMode: TextInput.Password
                    placeholderText: "Session token"
                    Layout.fillWidth: true
                }
                QQC2.Button {
                    text: "Save token"
                    enabled: tokenField.text.trim().length > 0
                    onClicked: {
                        Backend.signInToken(tokenField.text.trim())
                        tokenField.text = ""
                    }
                }
            }

            ColumnLayout {
                visible: window.snapshot.signedIn
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                QQC2.Label { text: "Included"; color: Kirigami.Theme.disabledTextColor }
                Meter {
                    title: "Cursor Models"
                    value: window.snapshot.cursor.text
                    fraction: window.snapshot.cursor.fraction
                    warning: window.snapshot.cursor.warning
                    tint: Kirigami.Theme.highlightColor
                }
                Meter {
                    title: "Other Models"
                    value: window.snapshot.other.text
                    fraction: window.snapshot.other.fraction
                    warning: window.snapshot.other.warning
                    tint: Qt.alpha(Kirigami.Theme.textColor, 0.55)
                }
            }

            ColumnLayout {
                visible: window.snapshot.signedIn && window.snapshot.onDemand
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                QQC2.Label { text: "On-demand"; color: Kirigami.Theme.disabledTextColor }
                MoneyRow {
                    label: "Usage"
                    value: window.snapshot.onDemand ? window.snapshot.onDemand.usageText : ""
                }
                MoneyRow {
                    label: "Spend limit"
                    value: window.snapshot.onDemand ? window.snapshot.onDemand.limitText : ""
                }
                UsageBar {
                    fraction: window.snapshot.onDemand ? window.snapshot.onDemand.fraction : 0
                    fillColor: (window.snapshot.onDemand && window.snapshot.onDemand.warning)
                               ? Kirigami.Theme.negativeTextColor
                               : Kirigami.Theme.neutralTextColor
                }
            }

            ColumnLayout {
                visible: window.snapshot.signedIn
                Layout.fillWidth: true
                QQC2.Label { text: "Tokens"; color: Kirigami.Theme.disabledTextColor }
                RowLayout {
                    Layout.fillWidth: true
                    TokenColumn { label: "Today"; value: window.snapshot.tokens.today }
                    TokenColumn { label: "7 days"; value: window.snapshot.tokens.week }
                    TokenColumn { label: "30 days"; value: window.snapshot.tokens.month }
                }
            }

            QQC2.Label {
                visible: window.snapshot.error
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Kirigami.Theme.neutralTextColor
                text: window.snapshot.error || ""
            }

            RowLayout {
                visible: window.snapshot.signedIn
                Layout.fillWidth: true
                QQC2.Label {
                    Layout.fillWidth: true
                    color: Kirigami.Theme.disabledTextColor
                    text: window.snapshot.updatedText ? ("Updated " + window.snapshot.updatedText + " · refreshes every 5 minutes") : ""
                    wrapMode: Text.WordWrap
                }
                QQC2.Button {
                    text: "Sign out"
                    onClicked: Backend.signOut()
                }
            }

            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Kirigami.Theme.disabledTextColor
                text: "Add the widget from the desktop: right-click the wallpaper, choose Add Widgets, and search for Cursor Usage. Clicking the widget does not open this window."
            }
        }
    }

    readonly property string subtitle: {
        if (!snapshot.signedIn)
            return "Not signed in"
        var parts = []
        if (snapshot.email)
            parts.push(snapshot.email)
        if (snapshot.membership)
            parts.push(snapshot.membership)
        return parts.length === 0 ? "Signed in" : parts.join(" · ")
    }
}

component UsageBar: Rectangle {
    id: bar
    property real fraction: 0
    property color fillColor: Kirigami.Theme.highlightColor
    Layout.fillWidth: true
    implicitHeight: 8
    radius: height / 2
    color: Qt.alpha(Kirigami.Theme.textColor, 0.16)
    Rectangle {
        width: Math.max(0, Math.min(1, bar.fraction)) * parent.width
        height: parent.height
        radius: parent.radius
        color: bar.fillColor
    }
}

component Meter: ColumnLayout {
    id: meter
    property string title
    property string value
    property real fraction: 0
    property bool warning: false
    property color tint: Kirigami.Theme.highlightColor
    Layout.fillWidth: true
    spacing: Kirigami.Units.smallSpacing
    RowLayout {
        Layout.fillWidth: true
        QQC2.Label {
            text: meter.title
            font.bold: true
            Layout.fillWidth: true
        }
        QQC2.Label {
            text: meter.value
            font.bold: true
            font.family: "monospace"
        }
    }
    UsageBar {
        fraction: meter.fraction
        fillColor: meter.warning ? Kirigami.Theme.negativeTextColor : meter.tint
    }
}

component MoneyRow: RowLayout {
    property string label
    property string value
    Layout.fillWidth: true
    QQC2.Label {
        text: label
        font.bold: true
        Layout.fillWidth: true
    }
    QQC2.Label {
        text: value
        font.bold: true
        font.family: "monospace"
    }
}

component TokenColumn: ColumnLayout {
    property string label
    property string value
    Layout.fillWidth: true
    spacing: 0
    QQC2.Label {
        text: label
        color: Kirigami.Theme.disabledTextColor
    }
    QQC2.Label {
        text: value
        font.bold: true
        font.family: "monospace"
    }
}
