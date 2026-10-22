#include "Backend.hpp"

#include <QByteArray>
#include <QDir>
#include <QFileInfo>
#include <QStandardPaths>

Backend::Backend(QObject *parent)
    : QObject(parent)
    , m_snapshotJson(QStringLiteral("{\"signedIn\":false,\"email\":\"\",\"membership\":\"\",\"cursor\":{\"text\":\"—\",\"fraction\":0,\"warning\":false},\"other\":{\"text\":\"—\",\"fraction\":0,\"warning\":false},\"onDemand\":null,\"tokens\":{\"today\":\"—\",\"week\":\"—\",\"month\":\"—\"},\"updatedText\":\"\",\"error\":null}")) {
    connect(&m_process, &QProcess::finished, this, [this](int, QProcess::ExitStatus) {
        const QByteArray output = m_process.readAllStandardOutput();
        if (!output.isEmpty()) {
            m_snapshotJson = QString::fromUtf8(output);
            emit snapshotChanged();
        }
        m_busy = false;
        emit busyChanged();
        if (!m_queued.isEmpty()) {
            m_active = m_queued;
            m_queued.clear();
            launch();
        }
    });
    connect(&m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error != QProcess::FailedToStart) {
            return;
        }
        m_busy = false;
        emit busyChanged();
    });
}

QString Backend::snapshotJson() const {
    return m_snapshotJson;
}

bool Backend::busy() const {
    return m_busy;
}

void Backend::showSnapshot() {
    start({QStringLiteral("show")});
}

void Backend::refresh() {
    start({QStringLiteral("refresh")});
}

void Backend::signInLocal() {
    start({QStringLiteral("sign-in"), QStringLiteral("--local")});
}

void Backend::signInToken(const QString &token) {
    const QByteArray encoded = token.trimmed().toUtf8().toBase64();
    start({QStringLiteral("sign-in"), QStringLiteral("--token-base64"), QString::fromLatin1(encoded)});
}

void Backend::signOut() {
    start({QStringLiteral("sign-out")});
}

void Backend::start(const QStringList &arguments) {
    if (m_process.state() != QProcess::NotRunning) {
        m_queued = arguments;
        return;
    }
    m_active = arguments;
    launch();
}

void Backend::launch() {
    const QString executable = program();
    if (executable.isEmpty()) {
        m_snapshotJson = QStringLiteral("{\"signedIn\":false,\"error\":\"cursor-tokens is not installed.\",\"cursor\":{\"text\":\"—\",\"fraction\":0,\"warning\":false},\"other\":{\"text\":\"—\",\"fraction\":0,\"warning\":false},\"onDemand\":null,\"tokens\":{\"today\":\"—\",\"week\":\"—\",\"month\":\"—\"},\"email\":\"\",\"membership\":\"\",\"updatedText\":\"\"}");
        emit snapshotChanged();
        return;
    }
    m_busy = true;
    emit busyChanged();
    m_process.start(executable, m_active);
}

QString Backend::program() const {
    const QString local = QDir::homePath() + QStringLiteral("/.local/bin/cursor-tokens");
    if (QFileInfo::exists(local)) {
        return local;
    }
    return QStandardPaths::findExecutable(QStringLiteral("cursor-tokens"));
}
