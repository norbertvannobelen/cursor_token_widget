#include "Backend.hpp"

#include <QCoreApplication>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QtQml>

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("Cursor Tokens"));
    QGuiApplication::setOrganizationDomain(QStringLiteral("org.tx"));
    QGuiApplication::setDesktopFileName(QStringLiteral("org.tx.cursortokenwidget"));

    Backend backend;
    qmlRegisterSingletonInstance("org.tx.cursortokens", 1, 0, "Backend", &backend);

    QQmlApplicationEngine engine;
    const QString qml = QCoreApplication::applicationDirPath() + QStringLiteral("/../share/cursor-tokens/Main.qml");
    engine.load(QUrl::fromLocalFile(qml));
    if (engine.rootObjects().isEmpty()) {
        return 1;
    }
    return QGuiApplication::exec();
}
