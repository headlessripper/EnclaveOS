// Enclave Shell — session services: user, power, recent files, and the
// command socket ("enclave-shell --toggle-start" from the Super key).
#pragma once
#include <QLocalServer>
#include <QObject>
#include <QVariantList>

class System : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString userName READ userName CONSTANT)
    Q_PROPERTY(QString userInitial READ userInitial CONSTANT)
    Q_PROPERTY(QString avatar READ avatar CONSTANT)
    Q_PROPERTY(bool live READ live CONSTANT)

public:
    explicit System(QObject *parent = nullptr);

    static QString socketPath();
    static bool sendCommand(const QString &command);   // client side
    bool listen();                                       // server side

    QString userName() const { return m_userName; }
    QString userInitial() const { return m_userName.left(1).toUpper(); }
    QString avatar() const;
    bool live() const;

    Q_INVOKABLE void powerOff();
    Q_INVOKABLE void reboot();
    Q_INVOKABLE void suspend();
    Q_INVOKABLE void logout();
    Q_INVOKABLE void lock();
    Q_INVOKABLE void openUrl(const QString &url);
    Q_INVOKABLE bool run(const QString &program, const QStringList &args = {});
    Q_INVOKABLE QVariantList recentFiles(int limit = 6) const;

signals:
    void command(const QString &name);

private:
    QString m_userName;
    QLocalServer m_server;
};
