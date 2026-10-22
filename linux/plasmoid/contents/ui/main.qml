import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

import "backend.js" as Backend

PlasmoidItem {
    id: root

    // Replaced with an absolute path by linux/scripts/install.sh.
    readonly property string bin: "@CURSOR_TOKENS_BIN@"
    readonly property int generation: Plasmoid.configuration.generation
    property var snapshot: ({
        "signedIn": false,
        "email": "",
        "membership": "",
        "cursor": { "text": "—", "fraction": 0, "warning": false },
        "other": { "text": "—", "fraction": 0, "warning": false },
        "onDemand": null,
        "tokens": { "today": "—", "week": "—", "month": "—" },
        "updatedText": "",
        "error": null
    })
    property string status: ""

    onGenerationChanged: run(["show"])

    preferredRepresentation: compactRepresentation
    activationTogglesExpanded: false
    toolTipMainText: "Cursor Usage"
    toolTipSubText: snapshot.signedIn
            ? (snapshot.cursor.text + " · " + snapshot.other.text)
            : "Sign in from Configure Cursor Usage"

    Layout.minimumWidth: Kirigami.Units.gridUnit * 9
    Layout.minimumHeight: Kirigami.Units.gridUnit * 11
    Layout.preferredWidth: Kirigami.Units.gridUnit * 11
    Layout.preferredHeight: Kirigami.Units.gridUnit * 13

    switchWidth: Kirigami.Units.gridUnit * 18
    switchHeight: Kirigami.Units.gridUnit * 22

    compactRepresentation: Component {
        CompactView {
            snapshot: root.snapshot
            note: root.status
        }
    }
    fullRepresentation: Component {
        DetailView { snapshot: root.snapshot }
    }

    Plasma5Support.DataSource {
        id: runner
        engine: "executable"
        onNewData: (sourceName, data) => {
            const text = data["stdout"] || ""
            if (text.length > 0) {
                try {
                    root.snapshot = JSON.parse(text)
                } catch (error) {
                    root.status = "Couldn't read the usage update."
                }
            }
            disconnectSource(sourceName)
        }
    }

    Timer {
        interval: 5 * 60 * 1000
        repeat: true
        running: true
        onTriggered: root.run(["refresh"])
    }

    Component.onCompleted: {
        root.run(["show"])
        root.run(["refresh"])
    }

    function run(args) {
        if (root.bin.indexOf("CURSOR_TOKENS_BIN") !== -1) {
            root.status = "cursor-tokens is not installed."
            return
        }
        runner.connectSource(Backend.command(root.bin, args))
    }
}
