#include "system.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QLocalSocket>
#include <QMimeDatabase>
#include <QProcess>
#include <QStandardPaths>
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
