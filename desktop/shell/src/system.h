// Enclave Shell — session services: user, power, recent files, and the
// command socket ("enclave-shell --toggle-start" from the Super key).
#pragma once
#include <QJSValue>
#include <QLocalServer>
#include <QObject>
#include <QRect>
#include <QVariantList>

class System : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString userName READ userName CONSTANT)
    Q_PROPERTY(QString userInitial READ userInitial CONSTANT)
    Q_PROPERTY(QString avatar READ avatar CONSTANT)
    Q_PROPERTY(bool live READ live CONSTANT)
    Q_PROPERTY(QString homePath READ homePath CONSTANT)
    // "hyprland", or the wlroots compositor the session names (ENCLAVE_COMPOSITOR).
    Q_PROPERTY(QString compositor READ compositorName CONSTANT)

public:
    explicit System(QObject *parent = nullptr);

    static QString socketPath();
    static bool sendCommand(const QString &command);   // client side
    bool listen();                                       // server side

    QString userName() const { return m_userName; }
    QString userInitial() const { return m_userName.left(1).toUpper(); }
    QString avatar() const;
    bool live() const;
    QString homePath() const;
    static QString compositor();
    QString compositorName() const { return compositor(); }
    // Run Lua in Hyprland (the `enclave` bridge in hyprland.lua).
    static void runHypr(const QString &lua);
    Q_INVOKABLE void hypr(const QString &lua) { runHypr(lua); }

    Q_INVOKABLE void powerOff();
    Q_INVOKABLE void reboot();
    Q_INVOKABLE void suspend();
    Q_INVOKABLE void logout();
    Q_INVOKABLE void lock();
    Q_INVOKABLE void openUrl(const QString &url);
    Q_INVOKABLE bool run(const QString &program, const QStringList &args = {});
    Q_INVOKABLE QVariantList recentFiles(int limit = 6) const;
    // Runs a short status command (volume, network, battery) without blocking
    // the UI; calls callback(stdout, exitCode) when done (killed after 3 s).
    Q_INVOKABLE void query(const QString &program, const QStringList &args, const QJSValue &callback,
                           int timeoutMs = 3000);
    // Small text files (/etc/os-release, /sys/...); empty when unreadable.
    Q_INVOKABLE QString readFile(const QString &path) const;
    // Tell the running shell something (Settings uses "reload-settings").
    Q_INVOKABLE bool shellCommand(const QString &name) { return sendCommand(name); }
    // Where a surface takes pointer input; an empty rect means everywhere.
    // Lets floating surfaces (the bubble) be click-through around themselves.
    Q_INVOKABLE void setInputRegion(QObject *window, const QRect &rect);
    // Small per-user shell state (bubble position...), ~/.config/enclave/shell.conf
    Q_INVOKABLE QVariant setting(const QString &key, const QVariant &fallback = {}) const;
    Q_INVOKABLE void setSetting(const QString &key, const QVariant &value);
    Q_INVOKABLE QStringList settingKeys(const QString &group) const;

    // Live figures for the desktop widgets: cpu/memory/disk as 0..1, and the
    // total network bytes received/sent (the widget turns these into rates).
    Q_INVOKABLE QVariantMap stats();

signals:
    void command(const QString &name);

private:
    QString m_userName;
    QLocalServer m_server;
    quint64 m_cpuIdle = 0, m_cpuTotal = 0;
};
