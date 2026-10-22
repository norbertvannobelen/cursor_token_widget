#pragma once

#include <QObject>
#include <QProcess>
#include <QString>
#include <QStringList>

class Backend : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString snapshotJson READ snapshotJson NOTIFY snapshotChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit Backend(QObject *parent = nullptr);

    QString snapshotJson() const;
    bool busy() const;

    Q_INVOKABLE void showSnapshot();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void signInLocal();
    Q_INVOKABLE void signInToken(const QString &token);
    Q_INVOKABLE void signOut();

signals:
    void snapshotChanged();
    void busyChanged();

private:
    void start(const QStringList &arguments);
    void launch();
    QString program() const;

    QProcess m_process;
    QString m_snapshotJson;
    QStringList m_active;
    QStringList m_queued;
    bool m_busy = false;
};
