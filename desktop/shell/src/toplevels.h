// Enclave Shell — open windows, via wlr-foreign-toplevel-management.
// Uses its own wl_display connection (plain libwayland-client, pumped by a
// QSocketNotifier) so it stays independent of Qt's private Wayland API.
#pragma once
#include "windowmanager.h"
#include <QAbstractListModel>
#include <QSocketNotifier>
#include <QVariantList>
#include <memory>

struct wl_display;
struct wl_registry;
struct wl_seat;
struct zwlr_foreign_toplevel_manager_v1;
struct zwlr_foreign_toplevel_handle_v1;

struct Toplevel {
    zwlr_foreign_toplevel_handle_v1 *handle = nullptr;
    QString title, appId;
    bool activated = false, minimized = false, maximized = false, fullscreen = false;
    bool ready = false;  // first "done" received
    // pending state, committed on "done"
    QString pTitle, pAppId;
    bool pActivated = false, pMinimized = false, pMaximized = false, pFullscreen = false;
};

class ToplevelModel : public QAbstractListModel, public WindowManager {
    Q_OBJECT
    Q_PROPERTY(QVariantList windows READ windows NOTIFY windowsChanged)
    Q_PROPERTY(int activeIndex READ activeIndex NOTIFY windowsChanged)
    Q_PROPERTY(QString activeTitle READ activeTitle NOTIFY windowsChanged)
    Q_PROPERTY(QString activeAppId READ activeAppId NOTIFY windowsChanged)
    Q_PROPERTY(bool activeMaximized READ activeMaximized NOTIFY windowsChanged)
    Q_PROPERTY(bool activeFullscreen READ activeFullscreen NOTIFY windowsChanged)
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)

public:
    enum Roles { TitleRole = Qt::UserRole + 1, AppIdRole, ActivatedRole, MinimizedRole,
                 MaximizedRole, FullscreenRole };
    explicit ToplevelModel(QObject *parent = nullptr);
    ~ToplevelModel() override;

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QVariantList windows() const;
    QString activeTitle() const;
    QString activeAppId() const;
    bool activeMaximized() const;
    bool activeFullscreen() const;

    // WindowManager
    int windowCount() const override { return m_items.size(); }
    Q_INVOKABLE void activate(int index) override;
    Q_INVOKABLE void minimize(int index) override;
    Q_INVOKABLE void toggleMaximize(int index) override;
    Q_INVOKABLE void close(int index) override;
    int activeIndex() const override;
    bool available() const override { return m_manager != nullptr; }

    // Windows-taskbar click: activate, or minimise if already in front.
    Q_INVOKABLE void toggleMinimize(int index);
    Q_INVOKABLE void minimizeAll();
    Q_INVOKABLE void activeMinimize() { minimize(activeIndex()); }
    Q_INVOKABLE void activeToggleMaximize() { toggleMaximize(activeIndex()); }
    Q_INVOKABLE void activeClose() { close(activeIndex()); }

    // wayland listener entry points (public for the C callbacks)
    void onGlobal(wl_registry *reg, uint32_t name, const char *iface, uint32_t version);
    void onToplevel(zwlr_foreign_toplevel_handle_v1 *handle);
    Toplevel *find(zwlr_foreign_toplevel_handle_v1 *handle);
    void onDone(zwlr_foreign_toplevel_handle_v1 *handle);
    void onClosed(zwlr_foreign_toplevel_handle_v1 *handle);
    void onFinished();

signals:
    void windowsChanged();
    void availableChanged();

private:
    void dispatch();
    void flush();
    bool valid(int index) const { return index >= 0 && index < m_items.size(); }

    wl_display *m_display = nullptr;
    wl_registry *m_registry = nullptr;
    wl_seat *m_seat = nullptr;
    zwlr_foreign_toplevel_manager_v1 *m_manager = nullptr;
    std::unique_ptr<QSocketNotifier> m_notifier;
    QList<Toplevel *> m_pending;   // announced, not yet "done"
    QList<Toplevel *> m_items;     // visible in the model
};
