#include "appregistry.h"

#include <QCollator>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QProcess>
#include <QStandardPaths>
#include <QTextStream>
#include <QXmlStreamReader>
#include <algorithm>

namespace {
const QString kMenuFile = "/usr/share/enclave/menus/enclave-applications.menu";
const QString kDefaultPins = "/usr/share/enclave/start-defaults.json";
const QSet<QString> kSettingsCategories = {
    "Settings", "X-XFCE-SettingsDialog", "X-XFCE-HardwareSettings",
    "X-XFCE-PersonalSettings", "X-XFCE-SystemSettings", "X-GNOME-NetworkSettings"};
// Desktops whose apps work in the Enclave session.
const QSet<QString> kOurDesktops = {"Enclave", "wlroots", "XFCE"};

QString userPinsPath()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
        + "/enclave/start.json";
}

QStringList appDirs()
{
    QStringList dirs;
    QString home = qEnvironmentVariable("XDG_DATA_HOME");
    if (home.isEmpty())
        home = QDir::homePath() + "/.local/share";
    dirs << home + "/applications";
    QString data = qEnvironmentVariable("XDG_DATA_DIRS");
    if (data.isEmpty())
        data = "/usr/local/share:/usr/share";
    for (const QString &d : data.split(':', Qt::SkipEmptyParts))
        dirs << d + "/applications";
    dirs.removeDuplicates();
    return dirs;
}

QStringList splitList(const QString &v)
{
    QStringList out;
    for (const QString &s : v.split(';', Qt::SkipEmptyParts))
        out << s.trimmed();
    return out;
}

// Unescape desktop-entry string values (\s \n \t \\).
QString unescape(QString v)
{
    v.replace("\\s", " ").replace("\\n", "\n").replace("\\t", "\t").replace("\\\\", "\\");
    return v;
}
} // namespace

AppRegistry::AppRegistry(QObject *parent) : QAbstractListModel(parent)
{
    m_reloadTimer.setSingleShot(true);
    m_reloadTimer.setInterval(800);
    connect(&m_reloadTimer, &QTimer::timeout, this, &AppRegistry::reload);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this,
            [this] { m_reloadTimer.start(); });
    loadMenuRules();
    loadPins();
    reload();
}

AppEntry AppRegistry::parseDesktopFile(const QString &path, const QString &id, bool *ok)
{
    AppEntry a;
    a.id = id;
    *ok = false;
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return a;

    const QString lang = QLocale().name();          // e.g. en_GB
    const QString shortLang = lang.section('_', 0, 0);
    QHash<QString, QString> kv;
    bool inEntry = false;
    QTextStream ts(&f);
    while (!ts.atEnd()) {
        const QString line = ts.readLine().trimmed();
        if (line.isEmpty() || line.startsWith('#'))
            continue;
        if (line.startsWith('[')) {
            if (inEntry)
                break;                                // only [Desktop Entry]
            inEntry = (line == "[Desktop Entry]");
            continue;
        }
        if (!inEntry)
            continue;
        const int eq = line.indexOf('=');
        if (eq <= 0)
            continue;
        kv.insert(line.left(eq).trimmed(), line.mid(eq + 1).trimmed());
    }
    auto loc = [&](const QString &key) {
        for (const QString &k : {key + "[" + lang + "]", key + "[" + shortLang + "]", key})
            if (kv.contains(k))
                return unescape(kv.value(k));
        return QString();
    };

    if (kv.value("Type") != "Application" || kv.value("NoDisplay") == "true"
        || kv.value("Hidden") == "true" || !kv.contains("Exec"))
        return a;
    const QStringList only = splitList(kv.value("OnlyShowIn"));
    if (!only.isEmpty()) {
        bool match = false;
        for (const QString &d : only)
            match |= kOurDesktops.contains(d);
        if (!match)
            return a;
    }
    for (const QString &d : splitList(kv.value("NotShowIn")))
        if (d == "Enclave")
            return a;
    const QString tryExec = kv.value("TryExec");
    if (!tryExec.isEmpty() && QStandardPaths::findExecutable(tryExec).isEmpty()
        && !QFileInfo(tryExec).isExecutable())
        return a;

    a.name = loc("Name");
    a.genericName = loc("GenericName");
    a.comment = loc("Comment");
    a.icon = kv.value("Icon");
    a.exec = kv.value("Exec");
    a.wmClass = kv.value("StartupWMClass");
    a.terminal = kv.value("Terminal") == "true";
    a.categories = splitList(kv.value("Categories"));
    a.keywords = splitList(loc("Keywords"));
    *ok = !a.name.isEmpty();
    return a;
}

void AppRegistry::loadMenuRules()
{
    // freedesktop menu rules, as used by enclave-applications.menu:
    // <Include><All/></Include>, then <Exclude> categories/files, then
    // <Include> files that are re-added.
    QFile f(kMenuFile);
    if (!f.open(QIODevice::ReadOnly)) {
        m_excludeCategories = kSettingsCategories;
        m_includeFiles = {"xfce-settings-manager.desktop"};
        return;
    }
    QXmlStreamReader xml(&f);
    enum { None, Include, Exclude } mode = None;
    while (!xml.atEnd()) {
        xml.readNext();
        if (xml.isStartElement()) {
            if (xml.name() == u"Include")
                mode = Include;
            else if (xml.name() == u"Exclude")
                mode = Exclude;
            else if (xml.name() == u"Category" && mode == Exclude)
                m_excludeCategories.insert(xml.readElementText().trimmed());
            else if (xml.name() == u"Filename") {
                const QString file = xml.readElementText().trimmed();
                (mode == Exclude ? m_excludeFiles : m_includeFiles).insert(file);
            }
        } else if (xml.isEndElement()
                   && (xml.name() == u"Include" || xml.name() == u"Exclude")) {
            mode = None;
        }
    }
}

bool AppRegistry::excluded(const AppEntry &a) const
{
    if (m_includeFiles.contains(a.id))
        return false;
    if (m_excludeFiles.contains(a.id))
        return true;
    for (const QString &c : a.categories)
        if (m_excludeCategories.contains(c))
            return true;
    return false;
}

void AppRegistry::reload()
{
    beginResetModel();
    m_apps.clear();
    m_all.clear();
    if (!m_watcher.directories().isEmpty())
        m_watcher.removePaths(m_watcher.directories());

    for (const QString &dir : appDirs()) {
        if (!QDir(dir).exists())
            continue;
        m_watcher.addPath(dir);
        QDirIterator it(dir, {"*.desktop"}, QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            const QString path = it.next();
            QString id = QDir(dir).relativeFilePath(path);
            id.replace('/', '-');
            if (m_all.contains(id))
                continue;                         // earlier XDG dir wins (overrides)
            bool ok = false;
            AppEntry a = parseDesktopFile(path, id, &ok);
            if (!ok) {
                m_all.insert(id, AppEntry{});     // hidden override still shadows
                continue;
            }
            for (const QString &c : a.categories)
                a.settings |= kSettingsCategories.contains(c);
            a.listed = !excluded(a);
            if (a.id == "xfce4-settings-editor.desktop")
                a.listed = false, a.settings = false;  // raw config tool: never shown
            m_all.insert(id, a);
        }
    }
    // drop the shadow placeholders
    for (auto it = m_all.begin(); it != m_all.end();)
        it = it->id.isEmpty() ? m_all.erase(it) : std::next(it);

    for (const AppEntry &a : std::as_const(m_all))
        if (a.listed)
            m_apps << a;
    QCollator coll;
    coll.setCaseSensitivity(Qt::CaseInsensitive);
    std::sort(m_apps.begin(), m_apps.end(),
              [&](const AppEntry &x, const AppEntry &y) { return coll.compare(x.name, y.name) < 0; });
    endResetModel();
    emit countChanged();
    emit pinsChanged();   // pins may now resolve to installed apps
}

int AppRegistry::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_apps.size();
}

QVariant AppRegistry::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_apps.size())
        return {};
    const AppEntry &a = m_apps.at(index.row());
    switch (role) {
    case IdRole: return a.id;
    case NameRole: return a.name;
    case IconRole: return a.icon;
    case CommentRole: return a.comment.isEmpty() ? a.genericName : a.comment;
    case LetterRole: {
        const QChar c = a.name.isEmpty() ? QChar('#') : a.name.at(0).toUpper();
        return c.isLetter() ? QString(c) : QStringLiteral("#");
    }
    }
    return {};
}

QHash<int, QByteArray> AppRegistry::roleNames() const
{
    return {{IdRole, "appId"}, {NameRole, "name"}, {IconRole, "icon"},
            {CommentRole, "comment"}, {LetterRole, "letter"}};
}

QVariantMap AppRegistry::app(const QString &id) const
{
    const auto it = m_all.constFind(id);
    if (it == m_all.constEnd())
        return {};
    return {{"appId", it->id}, {"name", it->name}, {"icon", it->icon},
            {"comment", it->comment.isEmpty() ? it->genericName : it->comment},
            {"settings", it->settings}};
}

QString AppRegistry::expandExec(const AppEntry &app)
{
    QString out;
    const QString &e = app.exec;
    for (int i = 0; i < e.size(); ++i) {
        if (e[i] != '%' || i + 1 >= e.size()) {
            out += e[i];
            continue;
        }
        const QChar code = e[++i];
        if (code == '%')
            out += '%';
        else if (code == 'i' && !app.icon.isEmpty())
            out += "--icon '" + app.icon + "'";
        else if (code == 'c')
            out += "'" + QString(app.name).replace('\'', "") + "'";
        // %f %F %u %U %d %D %n %N %k %v %m: no files/urls from the launcher
    }
    return out.simplified();
}

bool AppRegistry::launch(const QString &id)
{
    const auto it = m_all.constFind(id);
    if (it == m_all.constEnd())
        return false;
    QString cmd = expandExec(*it);
    if (it->terminal)
        cmd = "xfce4-terminal -x " + cmd;
    // setsid: apps outlive the shell (a shell restart must not kill them).
    return QProcess::startDetached("setsid", {"-f", "/bin/sh", "-c", "exec " + cmd},
                                   QDir::homePath());
}

QVariantList AppRegistry::search(const QString &query, int limit) const
{
    const QString q = query.trimmed().toLower();
    QVariantList out;
    if (q.isEmpty())
        return out;
    QList<QPair<int, const AppEntry *>> scored;
    for (const AppEntry &a : m_all) {
        if (!a.listed && !a.settings)
            continue;
        const QString name = a.name.toLower();
        int s = 0;
        if (name == q) s = 100;
        else if (name.startsWith(q)) s = 80;
        else if (name.contains(" " + q)) s = 65;
        else if (name.contains(q)) s = 50;
        else if (a.genericName.toLower().contains(q)) s = 40;
        else {
            for (const QString &k : a.keywords)
                if (k.toLower().startsWith(q)) { s = 35; break; }
            if (!s && a.comment.toLower().contains(q)) s = 20;
        }
        if (s)
            scored.append({s - (a.settings ? 5 : 0), &a});
    }
    std::stable_sort(scored.begin(), scored.end(), [](auto &x, auto &y) {
        return x.first != y.first ? x.first > y.first : x.second->name < y.second->name;
    });
    for (const auto &p : scored.mid(0, limit))
        out << app(p.second->id);
    return out;
}

QString AppRegistry::matchAppId(const QString &waylandAppId) const
{
    if (waylandAppId.isEmpty())
        return {};
    const QString w = waylandAppId.toLower();
    if (m_all.contains(waylandAppId + ".desktop"))
        return waylandAppId + ".desktop";
    for (const AppEntry &a : m_all) {
        const QString base = a.id.chopped(8).toLower();      // strip ".desktop"
        if (base == w || base.section('.', -1) == w || a.wmClass.toLower() == w)
            return a.id;
    }
    for (const AppEntry &a : m_all) {                         // last resort: binary
        const QString bin = QFileInfo(a.exec.section(' ', 0, 0)).fileName().toLower();
        if (!bin.isEmpty() && (bin == w || bin.startsWith(w + "-") || w.startsWith(bin)))
            return a.id;
    }
    return {};
}

// ---- pins -----------------------------------------------------------------

void AppRegistry::loadPins()
{
    auto read = [](const QString &path) {
        QFile f(path);
        return f.open(QIODevice::ReadOnly) ? QJsonDocument::fromJson(f.readAll()).object()
                                           : QJsonObject();
    };
    auto list = [](const QJsonValue &v) {
        QStringList out;
        for (const QJsonValue &x : v.toArray())
            out << x.toString();
        return out;
    };
    const QJsonObject defaults = read(kDefaultPins);
    const QJsonObject user = read(userPinsPath());
    m_startPins = list(user.contains("pinned") ? user["pinned"] : defaults["pinned"]);
    m_taskbarPins = list(user.contains("taskbar") ? user["taskbar"] : defaults["taskbar"]);
}

void AppRegistry::savePins() const
{
    QJsonObject o;
    {   // keep keys written by other tools (the X11 Start menu shares this file)
        QFile f(userPinsPath());
        if (f.open(QIODevice::ReadOnly))
            o = QJsonDocument::fromJson(f.readAll()).object();
    }
    o["pinned"] = QJsonArray::fromStringList(m_startPins);
    o["taskbar"] = QJsonArray::fromStringList(m_taskbarPins);
    QDir().mkpath(QFileInfo(userPinsPath()).path());
    QFile f(userPinsPath());
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        f.write(QJsonDocument(o).toJson());
}

void AppRegistry::pinStart(const QString &id, bool pinned)
{
    m_startPins.removeAll(id);
    if (pinned)
        m_startPins << id;
    savePins();
    emit pinsChanged();
}

void AppRegistry::pinTaskbar(const QString &id, bool pinned)
{
    m_taskbarPins.removeAll(id);
    if (pinned)
        m_taskbarPins << id;
    savePins();
    emit pinsChanged();
}

void AppRegistry::moveStartPinToFront(const QString &id)
{
    if (!m_startPins.removeAll(id))
        return;
    m_startPins.prepend(id);
    savePins();
    emit pinsChanged();
}
