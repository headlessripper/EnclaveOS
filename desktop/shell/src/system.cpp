#include "system.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QLocalSocket>
#include <QMimeDatabase>
#include <QProcess>
#include <QRegion>
#include <QSettings>
#include <QWindow>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QTimer>
#include <QUrl>
#include <QXmlStreamReader>
#include <algorithm>
#include <pwd.h>
#include <unistd.h>

System::System(QObject *parent) : QObject(parent)
{
    if (const passwd *pw = getpwuid(getuid())) {
        const QString gecos = QString::fromLocal8Bit(pw->pw_gecos).section(',', 0, 0).trimmed();
        m_userName = gecos.isEmpty() ? QString::fromLocal8Bit(pw->pw_name) : gecos;
        if (!m_userName.isEmpty())
            m_userName[0] = m_userName[0].toUpper();
    }
    connect(&m_server, &QLocalServer::newConnection, this, [this] {
        while (QLocalSocket *s = m_server.nextPendingConnection()) {
            connect(s, &QLocalSocket::readyRead, this, [this, s] {
                const QString cmd = QString::fromUtf8(s->readAll()).trimmed();
                if (!cmd.isEmpty())
                    emit command(cmd);
                s->disconnectFromServer();
            });
            connect(s, &QLocalSocket::disconnected, s, &QObject::deleteLater);
        }
    });
}

QString System::socketPath()
{
    QString dir = qEnvironmentVariable("XDG_RUNTIME_DIR");
    if (dir.isEmpty())
        dir = QDir::tempPath();
    QString display = qEnvironmentVariable("WAYLAND_DISPLAY", "wayland-0");
    return dir + "/enclave-shell-" + display + ".sock";
}

bool System::sendCommand(const QString &command)
{
    QLocalSocket s;
    s.connectToServer(socketPath());
    if (!s.waitForConnected(500))
        return false;
    s.write(command.toUtf8());
    s.waitForBytesWritten(500);
    s.disconnectFromServer();
    return true;
}

bool System::listen()
{
    QLocalServer::removeServer(socketPath());
    m_server.setSocketOptions(QLocalServer::UserAccessOption);
    return m_server.listen(socketPath());
}

QString System::avatar() const
{
    const QString face = QDir::homePath() + "/.face";
    return QFile::exists(face) ? face : QString();
}

QString System::homePath() const { return QDir::homePath(); }

bool System::live() const
{
    return QFile::exists("/run/archiso") || QFile::exists("/etc/sddm.conf.d/10-enclave-autologin.conf");
}

bool System::run(const QString &program, const QStringList &args)
{
    return QProcess::startDetached(program, args, QDir::homePath());
}

void System::powerOff() { run("systemctl", {"poweroff"}); }
void System::reboot() { run("systemctl", {"reboot"}); }
void System::suspend() { run("systemctl", {"suspend"}); }
void System::lock() { run("loginctl", {"lock-session"}); }
void System::openUrl(const QString &url) { run("xdg-open", {url}); }

void System::logout()
{
    // enclave-session exports the compositor's pid (whichever compositor it
    // is); SIGTERM ends the session cleanly.
    const QString pid = qEnvironmentVariable("ENCLAVE_COMPOSITOR_PID");
    if (!pid.isEmpty())
        run("kill", {"-TERM", pid});
    else
        run("loginctl", {"terminate-session", qEnvironmentVariable("XDG_SESSION_ID")});
}

void System::query(const QString &program, const QStringList &args, const QJSValue &callback)
{
    auto *p = new QProcess(this);
    auto done = [p, callback](const QString &out, int code) {
        if (callback.isCallable())
            QJSValue(callback).call({QJSValue(out), QJSValue(code)});
        p->deleteLater();
    };
    connect(p, &QProcess::finished, this, [p, done](int code, QProcess::ExitStatus) {
        done(QString::fromUtf8(p->readAllStandardOutput()).trimmed(), code);
    });
    connect(p, &QProcess::errorOccurred, this, [done](QProcess::ProcessError e) {
        if (e == QProcess::FailedToStart)
            done({}, -1);
    });
    QTimer::singleShot(3000, p, [p] {
        if (p->state() != QProcess::NotRunning)
            p->kill();
    });
    p->start(program, args);
}

void System::setInputRegion(QObject *window, const QRect &rect)
{
    if (auto *w = qobject_cast<QWindow *>(window))
        w->setMask(rect.isEmpty() ? QRegion() : QRegion(rect));
}

static QString shellConf()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
        + "/enclave/shell.conf";
}

QVariant System::setting(const QString &key, const QVariant &fallback) const
{
    return QSettings(shellConf(), QSettings::IniFormat).value(key, fallback);
}

void System::setSetting(const QString &key, const QVariant &value)
{
    QSettings(shellConf(), QSettings::IniFormat).setValue(key, value);
}

QVariantList System::recentFiles(int limit) const
{
    // GTK/GLib's shared recent-files list (XBEL), the same one Files uses.
    QFile f(QDir::homePath() + "/.local/share/recently-used.xbel");
    struct Item { QString path; QDateTime when; };
    QList<Item> items;
    if (f.open(QIODevice::ReadOnly)) {
        QXmlStreamReader xml(&f);
        while (!xml.atEnd()) {
            xml.readNext();
            if (!xml.isStartElement() || xml.name() != u"bookmark")
                continue;
            const QUrl url(xml.attributes().value("href").toString());
            if (!url.isLocalFile() || !QFileInfo::exists(url.toLocalFile()))
                continue;
            QString stamp = xml.attributes().value("visited").toString();
            if (stamp.isEmpty())
                stamp = xml.attributes().value("modified").toString();
            items.append({url.toLocalFile(), QDateTime::fromString(stamp, Qt::ISODateWithMs)});
        }
    }
    std::sort(items.begin(), items.end(), [](const Item &a, const Item &b) { return a.when > b.when; });
    QVariantList out;
    QMimeDatabase mimes;
    for (const Item &it : items.mid(0, limit)) {
        const QFileInfo fi(it.path);
        out << QVariantMap{{"title", fi.fileName()},
                           {"subtitle", it.when.isValid() ? it.when.toLocalTime().toString("d MMM, HH:mm")
                                                          : fi.absolutePath()},
                           {"icon", mimes.mimeTypeForFile(fi).iconName()},
                           {"url", QUrl::fromLocalFile(it.path).toString()}};
    }
    return out;
}

QVariantMap System::stats()
{
    QVariantMap out;
    // CPU: busy share since the previous call (/proc/stat "cpu" line).
    QFile stat("/proc/stat");
    if (stat.open(QIODevice::ReadOnly)) {
        const QList<QByteArray> f = stat.readLine().simplified().split(' ');
        quint64 total = 0, idle = 0;
        for (int i = 1; i < f.size(); ++i) {
            total += f[i].toULongLong();
            if (i == 4 || i == 5)            // idle + iowait
                idle += f[i].toULongLong();
        }
        const quint64 dt = total - m_cpuTotal, di = idle - m_cpuIdle;
        out["cpu"] = m_cpuTotal && dt ? 1.0 - double(di) / double(dt) : 0.0;
        m_cpuTotal = total;
        m_cpuIdle = idle;
    }
    // Memory: 1 - MemAvailable / MemTotal.
    QFile mem("/proc/meminfo");
    if (mem.open(QIODevice::ReadOnly)) {
        double total = 0, avail = 0;
        for (const QByteArray &line : mem.readAll().split('\n')) {
            const QList<QByteArray> f = line.simplified().split(' ');
            if (f.size() < 2) continue;
            if (f[0] == "MemTotal:") total = f[1].toDouble();
            else if (f[0] == "MemAvailable:") avail = f[1].toDouble();
        }
        out["memory"] = total > 0 ? 1.0 - avail / total : 0.0;
        out["memoryTotal"] = total * 1024.0;
    }
    // Disk: the home filesystem.
    const QStorageInfo disk(QDir::homePath());
    if (disk.isValid() && disk.bytesTotal() > 0) {
        out["disk"] = 1.0 - double(disk.bytesAvailable()) / double(disk.bytesTotal());
        out["diskTotal"] = double(disk.bytesTotal());
    }
    // Network: bytes in/out over every interface but loopback.
    QFile net("/proc/net/dev");
    if (net.open(QIODevice::ReadOnly)) {
        double rx = 0, tx = 0;
        for (const QByteArray &line : net.readAll().split('\n')) {
            const int colon = line.indexOf(':');
            if (colon < 0 || line.left(colon).trimmed() == "lo") continue;
            const QList<QByteArray> f = line.mid(colon + 1).simplified().split(' ');
            if (f.size() >= 9) { rx += f[0].toDouble(); tx += f[8].toDouble(); }
        }
        out["rx"] = rx;
        out["tx"] = tx;
    }
    return out;
}
