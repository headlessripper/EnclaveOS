// Enclave Files — the file manager's backend (enclave-shell --files).
//
// One folder at a time: its entries (name, kind, size, date, the icon to
// draw, whether it can show a thumbnail), back/forward history, the places
// sidebar (your folders, drives with their space, Trash), and the file
// operations — open, new folder, rename, cut/copy/paste (shared with other
// apps through the system clipboard), Move to Trash, empty Trash, search.
// The folder is watched, so changes made elsewhere show up at once.
#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QVariantList>

class Files : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString path READ path NOTIFY pathChanged)
    Q_PROPERTY(QString title READ title NOTIFY pathChanged)
    Q_PROPERTY(bool inTrash READ inTrash NOTIFY pathChanged)
    Q_PROPERTY(QVariantList crumbs READ crumbs NOTIFY pathChanged)
    Q_PROPERTY(bool canBack READ canBack NOTIFY pathChanged)
    Q_PROPERTY(bool canForward READ canForward NOTIFY pathChanged)
    Q_PROPERTY(bool canUp READ canUp NOTIFY pathChanged)
    Q_PROPERTY(QVariantList entries READ entries NOTIFY entriesChanged)
    Q_PROPERTY(QString freeText READ freeText NOTIFY entriesChanged)
    Q_PROPERTY(QVariantList places READ places NOTIFY placesChanged)
    Q_PROPERTY(QVariantList drives READ drives NOTIFY placesChanged)
    Q_PROPERTY(bool showHidden READ showHidden WRITE setShowHidden NOTIFY entriesChanged)
    Q_PROPERTY(QString sortKey READ sortKey WRITE setSortKey NOTIFY entriesChanged)
    Q_PROPERTY(bool sortDescending READ sortDescending WRITE setSortDescending NOTIFY entriesChanged)
    Q_PROPERTY(bool canPaste READ canPaste NOTIFY clipboardChanged)
    Q_PROPERTY(int busy READ busy NOTIFY busyChanged)

public:
    explicit Files(QObject *parent = nullptr);

    QString path() const { return m_path; }
    QString title() const;
    bool inTrash() const;
    QVariantList crumbs() const;
    bool canBack() const { return !m_back.isEmpty(); }
    bool canForward() const { return !m_forward.isEmpty(); }
    bool canUp() const;
    QVariantList entries() const { return m_entries; }
    QString freeText() const;
    QVariantList places() const;
    QVariantList drives() const;
    bool showHidden() const { return m_showHidden; }
    void setShowHidden(bool on);
    QString sortKey() const { return m_sortKey; }
    void setSortKey(const QString &key);
    bool sortDescending() const { return m_sortDesc; }
    void setSortDescending(bool on);
    bool canPaste() const;
    int busy() const { return m_busy; }

    // navigation
    Q_INVOKABLE void go(const QString &path);
    Q_INVOKABLE void back();
    Q_INVOKABLE void forward();
    Q_INVOKABLE void up();
    Q_INVOKABLE void refresh();
    // open a folder here, anything else in its app
    Q_INVOKABLE void open(const QString &path);
    Q_INVOKABLE void openTerminal(const QString &dir = QString());
    Q_INVOKABLE void openInNewWindow(const QString &dir);

    // file operations (paths are absolute)
    Q_INVOKABLE QString newFolder();
    Q_INVOKABLE QString rename(const QString &path, const QString &name);
    Q_INVOKABLE void copy(const QStringList &paths);
    Q_INVOKABLE void cut(const QStringList &paths);
    Q_INVOKABLE void paste();
    Q_INVOKABLE void trash(const QStringList &paths);
    Q_INVOKABLE void restore(const QStringList &paths);
    Q_INVOKABLE void deleteForever(const QStringList &paths);
    Q_INVOKABLE void emptyTrash();
    Q_INVOKABLE void copyPath(const QStringList &paths);

    Q_INVOKABLE QVariantList search(const QString &text) const;
    Q_INVOKABLE QVariantMap info(const QString &path) const;

signals:
    void pathChanged();
    void entriesChanged();
    void placesChanged();
    void clipboardChanged();
    void busyChanged();
    void message(const QString &text);

private:
    QVariantMap entry(const QString &path) const;
    void load();
    void setPath(const QString &path, bool record);
    void runJob(const QString &program, const QStringList &args);
    static QString trashFiles();
    static QString uniqueName(const QString &dir, const QString &name);

    QString m_path;
    QStringList m_back, m_forward;
    QVariantList m_entries;
    bool m_showHidden = false;
    QString m_sortKey = "name";
    bool m_sortDesc = false;
    QStringList m_clip;
    bool m_clipCut = false;
    int m_busy = 0;
    QFileSystemWatcher m_watch;
    QTimer m_reload;
};
