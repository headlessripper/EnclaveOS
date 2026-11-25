#include "files.h"

#include <QClipboard>
#include <QCollator>
#include <QDateTime>
#include <QDesktopServices>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QIcon>
#include <QLocale>
#include <QMimeData>
#include <QMimeDatabase>
#include <QProcess>
#include <QSettings>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QUrl>

#include <algorithm>

namespace {
const QString kTrash = QStringLiteral("trash");

QString home() { return QDir::homePath(); }

QString sizeText(qint64 bytes)
{
    return QLocale().formattedDataSize(bytes, 1, QLocale::DataSizeTraditionalFormat);
}

QString dateText(const QDateTime &dt)
{
    const QDate today = QDate::currentDate();
    const QString time = QLocale().toString(dt.time(), QLocale::ShortFormat);
    if (dt.date() == today)
        return QObject::tr("Today, %1").arg(time);
    if (dt.date() == today.addDays(-1))
        return QObject::tr("Yesterday, %1").arg(time);
    if (dt.date().year() == today.year())
        return QLocale().toString(dt.date(), "d MMM") + ", " + time;
    return QLocale().toString(dt.date(), "d MMM yyyy");
}

// The XDG folders get their own Enclave folder icons.
QString folderIcon(const QString &path)
{
    static const QList<QPair<QStandardPaths::StandardLocation, QString>> special = {
        {QStandardPaths::DesktopLocation, "user-desktop"},
        {QStandardPaths::DocumentsLocation, "folder-documents"},
        {QStandardPaths::DownloadLocation, "folder-download"},
        {QStandardPaths::MusicLocation, "folder-music"},
        {QStandardPaths::PicturesLocation, "folder-pictures"},
        {QStandardPaths::MoviesLocation, "folder-videos"},
    };
    if (path == home())
        return "user-home";
    for (const auto &s : special)
        if (QStandardPaths::writableLocation(s.first) == path)
            return s.second;
    return "folder";
}

void setClipboard(const QStringList &paths, bool cut)
{
    auto *data = new QMimeData;
    QList<QUrl> urls;
    QByteArray gnome = cut ? "cut" : "copy";
    for (const QString &p : paths) {
        const QUrl u = QUrl::fromLocalFile(p);
        urls << u;
        gnome += "\n" + u.toEncoded();
    }
    data->setUrls(urls);
    // what GTK file managers and most apps read for cut vs copy
    data->setData("x-special/gnome-copied-files", gnome);
    data->setText(paths.join('\n'));
    QGuiApplication::clipboard()->setMimeData(data);
}
} // namespace

Files::Files(QObject *parent) : QObject(parent)
{
    QSettings s("Enclave", "files");
    m_showHidden = s.value("showHidden", false).toBool();
    m_sortKey = s.value("sortKey", "name").toString();
    m_sortDesc = s.value("sortDescending", false).toBool();

    m_reload.setSingleShot(true);
    m_reload.setInterval(150);
    connect(&m_reload, &QTimer::timeout, this, &Files::load);
    connect(&m_watch, &QFileSystemWatcher::directoryChanged, this, [this] { m_reload.start(); });
    connect(QGuiApplication::clipboard(), &QClipboard::dataChanged, this, &Files::clipboardChanged);
    setPath(home(), false);
}

QString Files::trashFiles()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/Trash/files";
}

bool Files::inTrash() const { return m_path == kTrash; }

QString Files::title() const
{
    if (inTrash())
        return tr("Trash");
    if (m_path == home())
        return tr("Home");
    if (m_path == "/")
        return tr("Computer");
    return QFileInfo(m_path).fileName();
}

QVariantList Files::crumbs() const
{
    QVariantList out;
    if (inTrash()) {
        out << QVariantMap{{"name", tr("Trash")}, {"path", kTrash}};
        return out;
    }
    QString base = "/", rest = m_path;
    QString baseName = tr("Computer");
    if (m_path == home() || m_path.startsWith(home() + "/")) {
        base = home();
        baseName = tr("Home");
    }
    out << QVariantMap{{"name", baseName}, {"path", base}};
    rest = m_path.mid(base.length());
    QString acc = base;
    for (const QString &part : rest.split('/', Qt::SkipEmptyParts)) {
        acc = acc.endsWith('/') ? acc + part : acc + "/" + part;
        out << QVariantMap{{"name", part}, {"path", acc}};
    }
    return out;
}

bool Files::canUp() const { return !inTrash() && m_path != "/"; }

QString Files::freeText() const
{
    const QStorageInfo st(inTrash() ? home() : m_path);
    if (!st.isValid())
        return {};
    return tr("%1 free").arg(sizeText(st.bytesAvailable()));
}

QVariantList Files::places() const
{
    QVariantList out;
    out << QVariantMap{{"name", tr("Home")}, {"path", home()}, {"icon", "user-home"}};
    const QList<QPair<QStandardPaths::StandardLocation, QString>> list = {
        {QStandardPaths::DesktopLocation, tr("Desktop")},
        {QStandardPaths::DocumentsLocation, tr("Documents")},
        {QStandardPaths::DownloadLocation, tr("Downloads")},
        {QStandardPaths::MusicLocation, tr("Music")},
        {QStandardPaths::PicturesLocation, tr("Pictures")},
        {QStandardPaths::MoviesLocation, tr("Videos")},
    };
    for (const auto &l : list) {
        const QString p = QStandardPaths::writableLocation(l.first);
        if (p != home() && QFileInfo(p).isDir())
            out << QVariantMap{{"name", l.second}, {"path", p}, {"icon", folderIcon(p)}};
    }
    const bool full = !QDir(trashFiles()).isEmpty();
    out << QVariantMap{{"name", tr("Trash")}, {"path", kTrash}, {"icon", full ? "user-trash-full" : "user-trash"}};
    return out;
}

QVariantList Files::drives() const
{
    static const QStringList skipTypes = {"tmpfs", "devtmpfs", "proc", "sysfs", "efivarfs", "squashfs",
                                          "cgroup2", "securityfs", "debugfs", "tracefs", "fusectl",
                                          "configfs", "bpf", "pstore", "ramfs", "autofs", "mqueue"};
    QVariantList out;
    for (const QStorageInfo &st : QStorageInfo::mountedVolumes()) {
        if (!st.isValid() || !st.isReady())
            continue;
        const QString root = st.rootPath();
        const QString type = QString::fromLatin1(st.fileSystemType());
        if (skipTypes.contains(type))
            continue;
        if (root != "/" && !root.startsWith("/run/media/") && !root.startsWith("/media/")
            && !root.startsWith("/mnt/") && root != "/home")
            continue;
        const qint64 total = st.bytesTotal();
        if (total <= 0)
            continue;
        QString name = root == "/" ? tr("Enclave OS") : st.displayName();
        if (name.isEmpty() || name == root)
            name = QFileInfo(root).fileName();
        const bool removable = root.startsWith("/run/media/") || root.startsWith("/media/");
        out << QVariantMap{{"name", name}, {"path", root},
                           {"icon", removable ? "drive-removable-media" : "drive-harddisk"},
                           {"used", double(total - st.bytesAvailable()) / double(total)},
                           {"detail", tr("%1 free of %2").arg(sizeText(st.bytesAvailable()), sizeText(total))}};
    }
    return out;
}

void Files::setShowHidden(bool on)
{
    if (on == m_showHidden)
        return;
    m_showHidden = on;
    QSettings("Enclave", "files").setValue("showHidden", on);
    load();
}

void Files::setSortKey(const QString &key)
{
    if (key == m_sortKey || !QStringList{"name", "modified", "size", "kind"}.contains(key))
        return;
    m_sortKey = key;
    QSettings("Enclave", "files").setValue("sortKey", key);
    load();
}

void Files::setSortDescending(bool on)
{
    if (on == m_sortDesc)
        return;
    m_sortDesc = on;
    QSettings("Enclave", "files").setValue("sortDescending", on);
    load();
}

QVariantMap Files::entry(const QString &path) const
{
    static QMimeDatabase mimes;
    const QFileInfo fi(path);
    QVariantMap e;
    e["name"] = fi.fileName();
    e["path"] = fi.absoluteFilePath();
    e["dir"] = fi.isDir();
    e["hidden"] = fi.isHidden();
    e["link"] = fi.isSymLink();
    e["modified"] = fi.lastModified().toMSecsSinceEpoch();
    e["modifiedText"] = dateText(fi.lastModified());
    if (fi.isDir()) {
        const int n = QDir(path).entryList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::System).size();
        e["size"] = qint64(-1);
        e["sizeText"] = n == 1 ? tr("1 item") : tr("%1 items").arg(n);
        e["kind"] = tr("Folder");
        e["icon"] = folderIcon(fi.absoluteFilePath());
        e["image"] = false;
    } else {
        const QMimeType mt = mimes.mimeTypeForFile(fi);
        e["size"] = fi.size();
        e["sizeText"] = sizeText(fi.size());
        e["kind"] = mt.comment();
        e["icon"] = QIcon::hasThemeIcon(mt.iconName()) ? mt.iconName() : mt.genericIconName();
        e["image"] = mt.name().startsWith("image/") && fi.size() < 40 * 1024 * 1024;
    }
    return e;
}

void Files::load()
{
    const QString dir = inTrash() ? trashFiles() : m_path;
    QDir::Filters f = QDir::AllEntries | QDir::NoDotAndDotDot | QDir::System;
    if (m_showHidden)
        f |= QDir::Hidden;
    QVariantList list;
    for (const QFileInfo &fi : QDir(dir).entryInfoList(f))
        list << entry(fi.absoluteFilePath());

    QCollator coll;
    coll.setNumericMode(true);
    coll.setCaseSensitivity(Qt::CaseInsensitive);
    const QString key = m_sortKey;
    const bool desc = m_sortDesc;
    std::stable_sort(list.begin(), list.end(), [&](const QVariant &a, const QVariant &b) {
        const QVariantMap x = a.toMap(), y = b.toMap();
        if (x["dir"].toBool() != y["dir"].toBool())
            return x["dir"].toBool();               // folders first, always
        int c = 0;
        if (key == "modified")
            c = x["modified"].toLongLong() < y["modified"].toLongLong() ? -1
              : x["modified"].toLongLong() > y["modified"].toLongLong() ? 1 : 0;
        else if (key == "size")
            c = x["size"].toLongLong() < y["size"].toLongLong() ? -1
              : x["size"].toLongLong() > y["size"].toLongLong() ? 1 : 0;
        else if (key == "kind")
            c = coll.compare(x["kind"].toString(), y["kind"].toString());
        if (c == 0)
            c = coll.compare(x["name"].toString(), y["name"].toString());
        return desc ? c > 0 : c < 0;
    });
    m_entries = list;
    emit entriesChanged();
}

void Files::setPath(const QString &path, bool record)
{
    QString p = path;
    if (p == "trash:///" || p == "trash:" || p == "trash:/")
        p = kTrash;
    if (p != kTrash) {
        if (p.startsWith("file://"))
            p = QUrl(p).toLocalFile();
        if (p == "~" || p.isEmpty())
            p = home();
        else if (p.startsWith("~/"))
            p = home() + p.mid(1);
        p = QDir::cleanPath(QFileInfo(p).absoluteFilePath());
        if (!QFileInfo(p).isDir()) {
            emit message(tr("“%1” can’t be opened").arg(path));
            return;
        }
    }
    if (record && p != m_path) {
        m_back << m_path;
        m_forward.clear();
    }
    if (!m_watch.directories().isEmpty())
        m_watch.removePaths(m_watch.directories());
    m_path = p;
    m_watch.addPath(inTrash() ? trashFiles() : p);
    emit pathChanged();
    load();
}

void Files::go(const QString &path) { setPath(path, true); }

void Files::back()
{
    if (m_back.isEmpty())
        return;
    m_forward << m_path;
    setPath(m_back.takeLast(), false);
}

void Files::forward()
{
    if (m_forward.isEmpty())
        return;
    m_back << m_path;
    setPath(m_forward.takeLast(), false);
}

void Files::up()
{
    if (canUp())
        go(QFileInfo(m_path).dir().absolutePath());
}

void Files::refresh()
{
    load();
    emit placesChanged();
}

void Files::open(const QString &path)
{
    if (path == kTrash || QFileInfo(path).isDir()) {
        go(path);
        return;
    }
    if (inTrash()) {
        emit message(tr("Restore it from the Trash to open it"));
        return;
    }
    if (!QDesktopServices::openUrl(QUrl::fromLocalFile(path)))
        emit message(tr("No app can open “%1”").arg(QFileInfo(path).fileName()));
}

void Files::openTerminal(const QString &dir)
{
    const QString d = dir.isEmpty() ? (inTrash() ? home() : m_path) : dir;
    if (!QProcess::startDetached("enclave-terminal", {"--working-directory", d}, d))
        emit message(tr("Terminal could not be started"));
}

void Files::openInNewWindow(const QString &dir)
{
    QProcess::startDetached("enclave-files", {dir});
}

QString Files::uniqueName(const QString &dir, const QString &name)
{
    if (!QFileInfo::exists(dir + "/" + name))
        return name;
    const QFileInfo fi(name);
    const QString base = fi.completeBaseName().isEmpty() ? name : fi.completeBaseName();
    const QString ext = fi.completeBaseName().isEmpty() || fi.suffix().isEmpty() ? QString() : "." + fi.suffix();
    for (int i = 2;; ++i) {
        const QString n = QStringLiteral("%1 (%2)%3").arg(base).arg(i).arg(ext);
        if (!QFileInfo::exists(dir + "/" + n))
            return n;
    }
}

QString Files::newFolder()
{
    if (inTrash())
        return {};
    const QString name = uniqueName(m_path, tr("New Folder"));
    if (!QDir(m_path).mkdir(name)) {
        emit message(tr("A folder can’t be made here"));
        return {};
    }
    load();
    return m_path + "/" + name;
}

QString Files::rename(const QString &path, const QString &name)
{
    const QString n = name.trimmed();
    const QFileInfo fi(path);
    if (n.isEmpty() || n == fi.fileName())
        return path;
    if (n.contains('/')) {
        emit message(tr("Names can’t contain “/”"));
        return path;
    }
    const QString target = fi.absolutePath() + "/" + n;
    if (QFileInfo::exists(target)) {
        emit message(tr("“%1” already exists").arg(n));
        return path;
    }
    if (!QFile::rename(path, target)) {
        emit message(tr("“%1” couldn’t be renamed").arg(fi.fileName()));
        return path;
    }
    load();
    return target;
}

void Files::copy(const QStringList &paths)
{
    m_clip = paths;
    m_clipCut = false;
    setClipboard(paths, false);
    emit clipboardChanged();
}

void Files::cut(const QStringList &paths)
{
    m_clip = paths;
    m_clipCut = true;
    setClipboard(paths, true);
    emit clipboardChanged();
}

bool Files::canPaste() const
{
    if (inTrash())
        return false;
    const QMimeData *d = QGuiApplication::clipboard()->mimeData();
    return !m_clip.isEmpty() || (d && d->hasUrls());
}

void Files::runJob(const QString &program, const QStringList &args)
{
    auto *p = new QProcess(this);
    ++m_busy;
    emit busyChanged();
    connect(p, &QProcess::finished, this, [this, p](int code) {
        if (code != 0)
            emit message(tr("Some items couldn’t be copied or moved"));
        --m_busy;
        emit busyChanged();
        p->deleteLater();
        m_reload.start();
    });
    p->start(program, args);
}

void Files::paste()
{
    if (inTrash())
        return;
    // from another app's clipboard, if it was set there
    QStringList paths = m_clip;
    bool cut = m_clipCut;
    const QMimeData *d = QGuiApplication::clipboard()->mimeData();
    if (d && d->hasUrls()) {
        QStringList fromClip;
        for (const QUrl &u : d->urls())
            if (u.isLocalFile())
                fromClip << u.toLocalFile();
        if (fromClip != m_clip) {
            paths = fromClip;
            cut = d->data("x-special/gnome-copied-files").startsWith("cut");
        }
    }
    for (const QString &src : paths) {
        const QFileInfo fi(src);
        if (!fi.exists())
            continue;
        if (cut && fi.absolutePath() == m_path)
            continue;                       // moving onto itself
        if (fi.isDir() && (m_path == fi.absoluteFilePath() || m_path.startsWith(fi.absoluteFilePath() + "/"))) {
            emit message(tr("A folder can’t go inside itself"));
            continue;
        }
        const QString dst = m_path + "/" + uniqueName(m_path, fi.fileName());
        if (cut)
            runJob("mv", {"-n", "--", src, dst});
        else
            runJob("cp", {"-a", "--", src, dst});
    }
    if (cut) {
        m_clip.clear();
        QGuiApplication::clipboard()->clear();
        emit clipboardChanged();
    }
}

void Files::trash(const QStringList &paths)
{
    int failed = 0;
    for (const QString &p : paths)
        if (!QFile::moveToTrash(p))
            ++failed;
    if (failed)
        emit message(tr("%n item(s) couldn’t be moved to the Trash", nullptr, failed));
    load();
    emit placesChanged();
}

void Files::restore(const QStringList &paths)
{
    const QString infoDir = QFileInfo(trashFiles()).absolutePath() + "/info";
    for (const QString &p : paths) {
        const QString name = QFileInfo(p).fileName();
        const QString infoFile = infoDir + "/" + name + ".trashinfo";
        QSettings info(infoFile, QSettings::IniFormat);
        QString orig = QUrl::fromPercentEncoding(info.value("Trash Info/Path").toByteArray());
        if (orig.isEmpty()) {
            emit message(tr("“%1” has no original location").arg(name));
            continue;
        }
        QDir().mkpath(QFileInfo(orig).absolutePath());
        if (QFileInfo::exists(orig))
            orig = QFileInfo(orig).absolutePath() + "/" + uniqueName(QFileInfo(orig).absolutePath(), QFileInfo(orig).fileName());
        if (QFile::rename(p, orig))
            QFile::remove(infoFile);
        else
            emit message(tr("“%1” couldn’t be restored").arg(name));
    }
    load();
    emit placesChanged();
}

void Files::deleteForever(const QStringList &paths)
{
    const QString infoDir = QFileInfo(trashFiles()).absolutePath() + "/info";
    for (const QString &p : paths) {
        const QFileInfo fi(p);
        const bool ok = fi.isDir() && !fi.isSymLink() ? QDir(p).removeRecursively() : QFile::remove(p);
        if (!ok)
            emit message(tr("“%1” couldn’t be deleted").arg(fi.fileName()));
        if (fi.absolutePath() == trashFiles())
            QFile::remove(infoDir + "/" + fi.fileName() + ".trashinfo");
    }
    load();
    emit placesChanged();
}

void Files::emptyTrash()
{
    QStringList all;
    for (const QFileInfo &fi : QDir(trashFiles()).entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System))
        all << fi.absoluteFilePath();
    deleteForever(all);
}

void Files::copyPath(const QStringList &paths)
{
    QGuiApplication::clipboard()->setText(paths.join('\n'));
}

QVariantList Files::search(const QString &text) const
{
    QVariantList out;
    const QString needle = text.trimmed();
    if (needle.isEmpty())
        return out;
    QDir::Filters f = QDir::AllEntries | QDir::NoDotAndDotDot;
    if (m_showHidden)
        f |= QDir::Hidden;
    QDirIterator it(inTrash() ? trashFiles() : m_path, f, QDirIterator::Subdirectories);
    int seen = 0;
    while (it.hasNext() && out.size() < 400 && seen < 60000) {
        const QString p = it.next();
        ++seen;
        if (it.fileName().contains(needle, Qt::CaseInsensitive))
            out << entry(p);
    }
    return out;
}

QVariantMap Files::info(const QString &path) const
{
    QVariantMap e = entry(path);
    const QFileInfo fi(path);
    e["where"] = fi.absolutePath();
    e["created"] = dateText(fi.birthTime().isValid() ? fi.birthTime() : fi.lastModified());
    if (fi.isDir()) {
        qint64 total = 0;
        int count = 0;
        QDirIterator it(path, QDir::Files | QDir::Hidden | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
        while (it.hasNext() && count < 200000) {
            it.next();
            total += it.fileInfo().size();
            ++count;
        }
        e["sizeText"] = tr("%1 (%2 files)").arg(sizeText(total)).arg(count);
    }
    return e;
}
