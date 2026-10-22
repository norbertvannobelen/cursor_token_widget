#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
SHARE="${HOME}/.local/share/cursor-tokens"
BIN="${HOME}/.local/bin/cursor-tokens"
APP_DESKTOP="${HOME}/.local/share/applications/org.tx.cursortokenwidget.desktop"

if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required." >&2
    exit 1
fi

mkdir -p "${SHARE}" "${HOME}/.local/bin" "${HOME}/.local/share/applications"
rm -rf "${SHARE}/cursortokens"
cp -R "${ROOT}/cursortokens" "${SHARE}/cursortokens"
cat > "${BIN}" << EOF
#!/bin/sh
export PYTHONPATH="${SHARE}\${PYTHONPATH:+:\$PYTHONPATH}"
exec python3 -m cursortokens "\$@"
EOF
chmod 755 "${BIN}"

STAGE="$(mktemp -d)"
cleanup() { rm -rf "${STAGE}"; }
trap cleanup EXIT
cp -R "${ROOT}/plasmoid/." "${STAGE}/"
python3 - "${STAGE}" "${BIN}" << 'PY'
import pathlib, sys
stage, binary = sys.argv[1:]
for relative in ("contents/ui/main.qml", "contents/ui/configGeneral.qml"):
    path = pathlib.Path(stage, relative)
    path.write_text(path.read_text().replace("@CURSOR_TOKENS_BIN@", binary))
PY

if command -v kpackagetool6 >/dev/null 2>&1; then
    if kpackagetool6 --type Plasma/Applet --upgrade "${STAGE}" >/dev/null 2>&1; then
        echo "Updated the Cursor Usage widget."
    else
        kpackagetool6 --type Plasma/Applet --install "${STAGE}"
        echo "Installed the Cursor Usage widget."
    fi
else
    echo "kpackagetool6 was not found, so the widget was not registered." >&2
    echo "Install Plasma 6's package tools, then run this script again." >&2
fi

if command -v cmake >/dev/null 2>&1 && command -v pkg-config >/dev/null 2>&1; then
    BUILD="${ROOT}/build"
    mkdir -p "${BUILD}"
    if cmake -S "${ROOT}" -B "${BUILD}" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="${HOME}/.local"; then
        if cmake --build "${BUILD}" && cmake --install "${BUILD}"; then
            cp "${ROOT}/share/org.tx.cursortokenwidget.desktop" "${APP_DESKTOP}"
            echo "Installed the Cursor Tokens window to ${HOME}/.local/bin/cursor-tokens-app."
        else
            echo "The widget is installed. The window app did not build; Qt 6 and Kirigami 6 are required for that part." >&2
        fi
    else
        echo "The widget is installed. CMake could not find Qt 6 and Kirigami 6, so the window app was skipped." >&2
    fi
else
    echo "The widget is installed. cmake is required to build the Cursor Tokens window." >&2
fi

if command -v qdbus6 >/dev/null 2>&1 || command -v qdbus >/dev/null 2>&1; then
    QDBUS="$(command -v qdbus6 || command -v qdbus)"
    "${QDBUS}" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
        var desktop = desktops()[0]
        if (!desktop) { return }
        var widgets = desktop.widgets()
        for (var i = 0; i < widgets.length; i++) {
            if (widgets[i].type == "org.tx.cursortokenwidget") { return }
        }
        desktop.addWidget("org.tx.cursortokenwidget")
    ' >/dev/null 2>&1 || true
fi

echo "Add Cursor Usage from the desktop if it is not there yet: right-click the wallpaper, Add Widgets, then search for Cursor Usage."
echo "Sign in from the widget's Configure Cursor Usage action, or open Cursor Tokens from the application launcher."
