// Enclave Shell — the application catalogue.
// Built from standard XDG .desktop entries (no hard-coded app list), filtered
// by Enclave's de-cluttered menu rules (usr/share/enclave/menus/
// enclave-applications.menu). Also owns the Start and taskbar pins.
#pragma once
#include <QAbstractListModel>
#include <QFileSystemWatcher>
#include <QHash>
#include <QSet>
#include <QTimer>

struct AppEntry {
    QString id;          // desktop-file id, e.g. "org.mozilla.Thunderbird.desktop"
    QString name, genericName, comment, icon, exec, wmClass;
    QStringList categories, keywords;
    bool terminal = false;
    bool listed = true;  // shown in All apps (false: settings panels — search only)
    bool settings = false;
};

class AppRegistry : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(QStringList startPins READ startPins NOTIFY pinsChanged)
    Q_PROPERTY(QStringList taskbarPins READ taskbarPins NOTIFY pinsChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum Roles { IdRole = Qt::UserRole + 1, NameRole, IconRole, CommentRole, LetterRole };
    explicit AppRegistry(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QStringList startPins() const { return m_startPins; }
    QStringList taskbarPins() const { return m_taskbarPins; }

    Q_INVOKABLE QVariantMap app(const QString &id) const;
    Q_INVOKABLE bool launch(const QString &id);
    Q_INVOKABLE QVariantList search(const QString &query, int limit = 12) const;
    Q_INVOKABLE QString matchAppId(const QString &waylandAppId) const;  // -> desktop id
    Q_INVOKABLE void pinStart(const QString &id, bool pinned);
    Q_INVOKABLE void pinTaskbar(const QString &id, bool pinned);
    Q_INVOKABLE void moveStartPinToFront(const QString &id);
    Q_INVOKABLE void reload();

    // For tests and the CLI: exec line with field codes expanded.
    static QString expandExec(const AppEntry &app);
    static AppEntry parseDesktopFile(const QString &path, const QString &id, bool *ok);

signals:
    void pinsChanged();
    void countChanged();

private:
    void loadMenuRules();
    void loadPins();
    void savePins() const;
    bool excluded(const AppEntry &a) const;

    QList<AppEntry> m_apps;               // listed apps, sorted by name
    QHash<QString, AppEntry> m_all;       // every visible app incl. settings panels
    QStringList m_startPins, m_taskbarPins;
    QSet<QString> m_excludeCategories, m_excludeFiles, m_includeFiles;
    QFileSystemWatcher m_watcher;
    QTimer m_reloadTimer;
};
