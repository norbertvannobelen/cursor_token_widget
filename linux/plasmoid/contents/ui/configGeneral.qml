import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

import "backend.js" as Backend

Kirigami.FormLayout {
    id: page

    // Replaced with an absolute path by linux/scripts/install.sh.
    readonly property string bin: "@CURSOR_TOKENS_BIN@"

    Plasma5Support.DataSource {
        id: runner
        engine: "executable"
        onNewData: (sourceName, data) => {
            const text = data["stdout"] || ""
            try {
                const snapshot = JSON.parse(text)
                status.text = snapshot.error || (snapshot.signedIn ? "Signed in. The widget will show the latest figures." : "Signed out.")
                Plasmoid.configuration.generation = Plasmoid.configuration.generation + 1
            } catch (error) {
                status.text = (data["stderr"] || "Couldn't update the Cursor session.").trim()
            }
            disconnectSource(sourceName)
        }
    }

    QQC2.Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: "The widget reads the same figures as the Cursor dashboard and refreshes every 5 minutes. A click on the widget does not open a window. Sign in here."
    }

    QQC2.Button {
        text: "Use the account signed in to Cursor"
        onClicked: page.run(["sign-in", "--local"])
    }

    QQC2.Button {
        text: "Open cursor.com to copy a token"
        onClicked: page.runExternal("xdg-open https://cursor.com/dashboard")
    }

    QQC2.TextField {
        id: tokenField
        Kirigami.FormData.label: "Session token:"
        echoMode: TextInput.Password
        placeholderText: "WorkosCursorSessionToken"
        Layout.fillWidth: true
    }

    QQC2.Button {
        text: "Save token"
        enabled: tokenField.text.trim().length > 0
        onClicked: {
            page.run(["sign-in", "--token-base64", Qt.btoa(tokenField.text.trim())])
            tokenField.text = ""
        }
    }

    QQC2.Button {
        text: "Sign out"
        onClicked: page.run(["sign-out"])
    }

    QQC2.Label {
        id: status
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: ""
    }

    function run(args) {
        if (page.bin.indexOf("CURSOR_TOKENS_BIN") !== -1) {
            status.text = "cursor-tokens is not installed."
            return
        }
        runner.connectSource(Backend.command(page.bin, args))
    }

    function runExternal(command) {
        runner.connectSource(command)
    }
}
